"""Analysis job queue (TASK-029): SQLite-persisted jobs + in-process worker.

No Redis/Celery (research/background-jobs.md) — a `jobs` table and one
asyncio worker task, kicked when an upload completes and recovered on
startup. Every test injects a fake PipelineRunner; the ML extras are never
imported here.
"""

import time
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
