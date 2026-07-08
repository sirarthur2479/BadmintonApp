"""Analysis job queue (TASK-029): SQLite-persisted jobs + in-process worker.

No Redis/Celery (research/background-jobs.md) — a `jobs` table and one
asyncio worker task, kicked when an upload completes and recovered on
startup. Every test injects a fake PipelineRunner; the ML extras are never
imported here.
"""

from app.database import get_conn
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
    assert job["status"] == "queued"
    assert job["createdAt"]
    assert job["startedAt"] is None and job["finishedAt"] is None


def test_incomplete_upload_enqueues_nothing(client, auth_headers, settings):
    player_id = make_player(client, auth_headers)
    location = create_upload(
        client, auth_headers, player_id, length=64
    ).headers["Location"]
    patch_chunk(client, auth_headers, location, 0, b"v" * 32)  # half the bytes

    with get_conn(settings) as conn:
        assert conn.execute("SELECT COUNT(*) c FROM jobs").fetchone()["c"] == 0
