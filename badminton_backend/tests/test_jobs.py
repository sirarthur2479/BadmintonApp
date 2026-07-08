"""Analysis job queue (TASK-029): SQLite-persisted jobs + in-process worker.

No Redis/Celery (research/background-jobs.md) — a `jobs` table and one
asyncio worker task, kicked when an upload completes and recovered on
startup. Every test injects a fake PipelineRunner; the ML extras are never
imported here.
"""

import threading
import time
from pathlib import Path

import pytest
from contextlib import contextmanager

from fastapi.testclient import TestClient

from app.database import get_conn, init_db
from app.jobs import PipelineResult
from app.main import create_app
from tests.conftest import register_and_login
from tests.test_uploads import TUS, create_upload, make_player, patch_chunk


def complete_upload(client, auth_headers, player_id, *, session_id="sess-1",
                    mode="footwork", body=b"v" * 32):
    """Create + fully PATCH an upload; returns the upload id."""
    location = create_upload(
        client, auth_headers, player_id, length=len(body),
        session_id=session_id, mode=mode,
    ).headers["Location"]
    resp = patch_chunk(client, auth_headers, location, 0, body)
    assert resp.status_code == 204, resp.text
    return location.rsplit("/", 1)[1]


# --- Slice 1: completed upload enqueues a job ---


def test_upload_complete_enqueues_queued_job(client, auth_headers, settings):
    player_id = make_player(client, auth_headers)

    upload_id = complete_upload(
        client, auth_headers, player_id, session_id="sess-42", mode="biomech"
    )

    with get_conn(settings) as conn:
        job = conn.execute("SELECT * FROM jobs").fetchone()
        upload = conn.execute(
            "SELECT * FROM uploads WHERE id = ?", (upload_id,)
        ).fetchone()
    assert job is not None
    assert job["playerId"] == player_id
    assert job["sessionId"] == "sess-42"
    assert job["mode"] == "biomech"
    assert job["videoPath"] == upload["storage_path"]
    # The kick is async: by the time we query, the worker may have claimed
    # the job already (the default runner is not wired in this fixture, so
    # it can also have failed the claim's processing — enqueue is what this
    # test owns; terminal transitions are covered below).
    assert job["status"] in ("queued", "analyzing", "failed")
    assert job["createdAt"]


def test_incomplete_upload_enqueues_nothing(client, auth_headers, settings):
    player_id = make_player(client, auth_headers)
    location = create_upload(
        client, auth_headers, player_id, length=64
    ).headers["Location"]
    patch_chunk(client, auth_headers, location, 0, b"v" * 32)  # half the bytes

    with get_conn(settings) as conn:
        assert conn.execute("SELECT COUNT(*) c FROM jobs").fetchone()["c"] == 0


# --- Slice 2: worker processes queued jobs ---


def wait_for_job(settings, *, timeout=5.0):
    """Poll until the single jobs row reaches a terminal state."""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        with get_conn(settings) as conn:
            row = conn.execute("SELECT * FROM jobs").fetchone()
        if row is not None and row["status"] in ("done", "failed"):
            return row
        time.sleep(0.02)
    raise AssertionError(f"job never finished: {dict(row) if row else None}")


@contextmanager
def client_with_runner(settings, runner):
    with TestClient(create_app(settings, runner=runner)) as c:
        yield c


def test_worker_marks_analyzing_then_done_with_report_paths(settings):
    def runner(video_path, mode, out_dir):
        return PipelineResult(
            report_path=f"{out_dir}/report.md", court_map_path=f"{out_dir}/map.png"
        )

    with client_with_runner(settings, runner) as client:
        headers = register_and_login(client)
        player_id = make_player(client, headers)
        complete_upload(client, headers, player_id)

        job = wait_for_job(settings)

    assert job["status"] == "done"
    assert job["reportPath"].endswith("report.md")
    assert job["courtMapPath"].endswith("map.png")
    assert job["startedAt"] and job["finishedAt"]
    assert job["errorMessage"] is None


def test_worker_failure_marks_failed_with_error_message(settings):
    def runner(video_path, mode, out_dir):
        raise ValueError("court corners not found")

    with client_with_runner(settings, runner) as client:
        headers = register_and_login(client)
        player_id = make_player(client, headers)
        complete_upload(client, headers, player_id)

        job = wait_for_job(settings)

    assert job["status"] == "failed"
    assert "court corners not found" in job["errorMessage"]
    assert job["startedAt"] and job["finishedAt"]
    assert job["reportPath"] is None and job["courtMapPath"] is None


def test_extras_missing_message_stored_verbatim(settings):
    class ExtrasMissingError(RuntimeError):
        """Same shape as badminton_track.errors.ExtrasMissingError (the ML
        extras are deliberately not installed in the backend test env)."""

    message = "footwork mode needs extras: pip install 'badminton-track[cv]'"

    def runner(video_path, mode, out_dir):
        raise ExtrasMissingError(message)

    with client_with_runner(settings, runner) as client:
        headers = register_and_login(client)
        player_id = make_player(client, headers)
        complete_upload(client, headers, player_id)

        job = wait_for_job(settings)

    assert job["status"] == "failed"
    assert job["errorMessage"] == message


def test_jobs_run_one_at_a_time(settings):
    active = []
    max_active = []

    def runner(video_path, mode, out_dir):
        active.append(1)
        max_active.append(len(active))
        time.sleep(0.05)
        active.pop()
        return PipelineResult(report_path="r.md", court_map_path="")

    with client_with_runner(settings, runner) as client:
        headers = register_and_login(client)
        player_id = make_player(client, headers)
        complete_upload(client, headers, player_id, session_id="s1")
        complete_upload(client, headers, player_id, session_id="s2")

        deadline = time.monotonic() + 5.0
        while time.monotonic() < deadline:
            with get_conn(settings) as conn:
                done = conn.execute(
                    "SELECT COUNT(*) c FROM jobs WHERE status = 'done'"
                ).fetchone()["c"]
            if done == 2:
                break
            time.sleep(0.02)

    assert done == 2
    assert max(max_active) == 1


# --- Slice 3: startup recovery ---


def seed_job(settings, *, status, job_id="job-1"):
    """Insert account -> player -> job directly; simulates rows left behind
    by a process that died."""
    init_db(settings)
    with get_conn(settings) as conn:
        conn.execute(
            "INSERT INTO accounts (id, email, password_hash, created_at)"
            " VALUES ('acc-1', 'a@b.c', 'x', 'now')"
        )
        conn.execute(
            "INSERT INTO players (id, accountId, name) VALUES"
            " ('pl-1', 'acc-1', 'Kid')"
        )
        conn.execute(
            "INSERT INTO jobs (id, playerId, sessionId, videoPath, mode,"
            " status, createdAt, startedAt) VALUES (?, 'pl-1', 's', 'v.mp4',"
            " 'footwork', ?, 'now', ?)",
            (job_id, status, "now" if status == "analyzing" else None),
        )


def test_startup_recovery_fails_orphaned_analyzing_jobs(settings):
    seed_job(settings, status="analyzing")

    def runner(video_path, mode, out_dir):
        raise AssertionError("an interrupted job must never be re-run")

    with client_with_runner(settings, runner):
        pass  # startup hook runs on enter

    with get_conn(settings) as conn:
        job = conn.execute("SELECT * FROM jobs").fetchone()
    assert job["status"] == "failed"
    assert job["errorMessage"] == "interrupted by server restart"
    assert job["finishedAt"]


def test_startup_recovery_rekicks_queued_jobs(settings):
    seed_job(settings, status="queued")

    def runner(video_path, mode, out_dir):
        return PipelineResult(report_path="r.md", court_map_path="")

    with client_with_runner(settings, runner):
        job = wait_for_job(settings)

    assert job["status"] == "done"
    assert job["reportPath"] == "r.md"


# --- Slice 4: job status routes ---


def test_get_job_by_id_and_foreign_account_404(settings):
    def runner(video_path, mode, out_dir):
        return PipelineResult(report_path="r.md", court_map_path="m.png")

    with client_with_runner(settings, runner) as client:
        headers = register_and_login(client)
        player_id = make_player(client, headers)
        complete_upload(client, headers, player_id, session_id="sess-9")
        job = wait_for_job(settings)

        resp = client.get(f"/api/v1/jobs/{job['id']}", headers=headers)
        assert resp.status_code == 200
        body = resp.json()
        assert body["id"] == job["id"]
        assert body["sessionId"] == "sess-9"
        assert body["status"] == "done"
        assert body["mode"] == "footwork"
        assert body["errorMessage"] is None

        other = register_and_login(client, email="snoop@example.com")
        foreign = client.get(f"/api/v1/jobs/{job['id']}", headers=other)
        assert foreign.status_code == 404
        assert foreign.json()["detail"] == "job not found"

        unknown = client.get("/api/v1/jobs/nope", headers=headers)
        assert unknown.status_code == 404


def test_list_jobs_by_session_id_newest_first(settings):
    def runner(video_path, mode, out_dir):
        return PipelineResult(report_path="r.md", court_map_path="")

    with client_with_runner(settings, runner) as client:
        headers = register_and_login(client)
        player_id = make_player(client, headers)
        first = complete_upload(client, headers, player_id, session_id="sess-A")
        complete_upload(client, headers, player_id, session_id="sess-A")
        complete_upload(client, headers, player_id, session_id="sess-B")
        assert first  # three uploads, three jobs

        resp = client.get("/api/v1/jobs", params={"sessionId": "sess-A"},
                          headers=headers)
        assert resp.status_code == 200
        jobs = resp.json()
        assert len(jobs) == 2
        assert all(j["sessionId"] == "sess-A" for j in jobs)
        assert jobs[0]["createdAt"] >= jobs[1]["createdAt"]

        other = register_and_login(client, email="snoop2@example.com")
        assert other != headers
        empty = client.get("/api/v1/jobs", params={"sessionId": "sess-A"},
                           headers=other)
        assert empty.status_code == 200
        assert empty.json() == []


def test_jobs_routes_require_auth(client):
    assert client.get("/api/v1/jobs/x").status_code == 401
    assert client.get("/api/v1/jobs", params={"sessionId": "s"}).status_code == 401


# --- Slice 5: real pipeline runner (lazy badminton_track import) ---


def test_real_runner_reports_missing_extras_as_failed_job(settings):
    """badminton_track is deliberately NOT installed in the backend venv:
    the default runner must turn that into an actionable failed job, not a
    server crash."""
    with TestClient(create_app(settings)) as client:  # default runner
        headers = register_and_login(client)
        player_id = make_player(client, headers)
        complete_upload(client, headers, player_id)

        job = wait_for_job(settings)

    assert job["status"] == "failed"
    assert "badminton_track" in job["errorMessage"]
    assert "install" in job["errorMessage"]


def _fake_track_package(monkeypatch, tmp_path, *, biomech_windows):
    """Install a minimal fake badminton_track into sys.modules."""
    import sys
    import types

    calls = {}

    pkg = types.ModuleType("badminton_track")
    config_mod = types.ModuleType("badminton_track.config")
    cfg = types.SimpleNamespace(
        footwork=types.SimpleNamespace(
            data_dir=tmp_path, max_gap_s=0.5, base_point_m=(3.05, 8.68),
            base_radius_m=1.0,
        ),
        biomech=types.SimpleNamespace(),
        coach=types.SimpleNamespace(),
    )
    config_mod.load_config = lambda path: cfg

    coach_mod = types.ModuleType("badminton_track.coach")
    coach_mod.build_summary = lambda stats, aggregates, rows: {
        "stats": stats, "aggregates": aggregates, "rows": rows,
    }
    def produce_report(summary, coach_cfg):
        calls["summary"] = summary
        return "# Coach Report\nfake"

    coach_mod.produce_report = produce_report

    biomech_mod = types.ModuleType("badminton_track.biomech")
    biomech_mod.run_biomech = lambda video, cfg_b: biomech_windows

    pkg.coach = coach_mod
    pkg.biomech = biomech_mod
    monkeypatch.setitem(sys.modules, "badminton_track", pkg)
    monkeypatch.setitem(sys.modules, "badminton_track.config", config_mod)
    monkeypatch.setitem(sys.modules, "badminton_track.coach", coach_mod)
    monkeypatch.setitem(sys.modules, "badminton_track.biomech", biomech_mod)
    return calls


def test_real_runner_biomech_mode_writes_report_no_court_map(
    monkeypatch, tmp_path
):
    calls = _fake_track_package(monkeypatch, tmp_path, biomech_windows=["w1"])

    from app.jobs import real_pipeline_runner

    out_dir = tmp_path / "out"
    out_dir.mkdir()
    result = real_pipeline_runner("v.mp4", "biomech", str(out_dir))

    report = Path(result.report_path)
    assert report.read_text().startswith("# Coach Report")
    assert result.court_map_path == ""
    assert calls["summary"]["rows"] == ["w1"]


def test_real_runner_footwork_mode_requires_calibration(monkeypatch, tmp_path):
    _fake_track_package(monkeypatch, tmp_path, biomech_windows=[])

    from app.jobs import real_pipeline_runner

    with pytest.raises(RuntimeError, match="calibration"):
        real_pipeline_runner("v.mp4", "footwork", str(tmp_path))


# --- Slice: artifact download routes (TASK-034) ---


def test_report_and_court_map_download_when_done(settings, tmp_path):
    report = tmp_path / "coach-report.md"
    report.write_text("# Coach Report\nwell played")
    court_map = tmp_path / "court-map.png"
    court_map.write_bytes(b"\x89PNG fake")

    def runner(video_path, mode, out_dir):
        return PipelineResult(
            report_path=str(report), court_map_path=str(court_map)
        )

    with client_with_runner(settings, runner) as client:
        headers = register_and_login(client)
        player_id = make_player(client, headers)
        complete_upload(client, headers, player_id)
        job = wait_for_job(settings)

        got_report = client.get(
            f"/api/v1/jobs/{job['id']}/report", headers=headers
        )
        assert got_report.status_code == 200
        assert got_report.text == "# Coach Report\nwell played"

        got_map = client.get(
            f"/api/v1/jobs/{job['id']}/court-map", headers=headers
        )
        assert got_map.status_code == 200
        assert got_map.content == b"\x89PNG fake"


def test_artifact_routes_404_until_done_and_for_foreign_account(settings):
    block = threading.Event()

    def runner(video_path, mode, out_dir):
        block.wait(timeout=10)
        return PipelineResult(report_path="r.md", court_map_path="")

    with client_with_runner(settings, runner) as client:
        headers = register_and_login(client)
        player_id = make_player(client, headers)
        complete_upload(client, headers, player_id)

        with get_conn(settings) as conn:
            job_id = conn.execute("SELECT id FROM jobs").fetchone()["id"]

        # Not done yet -> 404 (job exists, artifact doesn't).
        assert (
            client.get(f"/api/v1/jobs/{job_id}/report", headers=headers)
            .status_code
            == 404
        )
        block.set()
        wait_for_job(settings)

        other = register_and_login(client, email="snoop3@example.com")
        assert (
            client.get(f"/api/v1/jobs/{job_id}/report", headers=other)
            .status_code
            == 404
        )
        # done but no court map (biomech-style empty path) -> 404 too.
        assert (
            client.get(f"/api/v1/jobs/{job_id}/court-map", headers=headers)
            .status_code
            == 404
        )
