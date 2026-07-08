"""tus Core + Creation subset (TASK-028).

The wire protocol is hand-rolled (research/resumable-upload.md): these tests
are the contract the Flutter `tusc` client relies on, so header names,
status codes, and offset semantics follow the tus 1.0.0 spec exactly.
"""

import base64
import uuid
from pathlib import Path

from app.database import get_conn
from tests.conftest import register_and_login

TUS = {"Tus-Resumable": "1.0.0"}


def _metadata(**pairs: str) -> str:
    """Encode an Upload-Metadata header: comma-separated `key base64(value)`."""
    return ",".join(
        f"{k} {base64.b64encode(v.encode()).decode()}" for k, v in pairs.items()
    )


def make_player(client, auth_headers) -> str:
    player_id = str(uuid.uuid4())
    resp = client.post(
        "/api/v1/players",
        json={
            "id": player_id,
            "name": "Kid One",
            "age": 12,
            "club": "",
            "playingStyle": "",
            "preferredGrip": "",
            "shortTermGoal": "",
            "longTermGoal": "",
            "photoPath": None,
        },
        headers=auth_headers,
    )
    assert resp.status_code == 201, resp.text
    return player_id


def create_upload(
    client,
    auth_headers,
    player_id: str,
    length: int = 64,
    session_id: str = "local-session-1",
    mode: str = "footwork",
):
    return client.post(
        "/api/v1/uploads",
        headers={
            **auth_headers,
            **TUS,
            "Upload-Length": str(length),
            "Upload-Metadata": _metadata(
                filename="clip.mp4",
                playerId=player_id,
                sessionId=session_id,
                mode=mode,
            ),
        },
    )


# --- Slice 1: OPTIONS discovery + POST creation ---


def test_options_advertises_tus_core_and_creation(client, auth_headers):
    resp = client.options("/api/v1/uploads", headers=auth_headers)
    assert resp.status_code == 204
    assert resp.headers["Tus-Resumable"] == "1.0.0"
    assert resp.headers["Tus-Version"] == "1.0.0"
    assert resp.headers["Tus-Extension"] == "creation"
    assert int(resp.headers["Tus-Max-Size"]) == 4 * 1024**3


def test_create_upload_returns_location_and_zero_offset(client, auth_headers):
    player_id = make_player(client, auth_headers)

    resp = create_upload(client, auth_headers, player_id)

    assert resp.status_code == 201, resp.text
    assert resp.headers["Tus-Resumable"] == "1.0.0"
    location = resp.headers["Location"]
    assert "/api/v1/uploads/" in location


def test_create_parses_metadata_and_scopes_to_own_player(
    client, auth_headers, settings
):
    player_id = make_player(client, auth_headers)

    resp = create_upload(client, auth_headers, player_id, session_id="sess-42")
    assert resp.status_code == 201

    # The row landed with parsed metadata and a real zero-length file on disk.
    with get_conn(settings) as conn:
        row = conn.execute("SELECT * FROM uploads").fetchone()
    assert row["playerId"] == player_id
    assert row["sessionId"] == "sess-42"
    assert row["mode"] == "footwork"
    assert row["filename"] == "clip.mp4"
    assert row["total_bytes"] == 64
    assert row["offset_bytes"] == 0
    assert row["status"] == "in_progress"
    stored = Path(row["storage_path"])
    assert stored.exists() and stored.stat().st_size == 0


def test_create_foreign_player_404(client, auth_headers):
    other_headers = register_and_login(client, email="other@example.com")
    foreign_player = make_player(client, other_headers)

    resp = create_upload(client, auth_headers, foreign_player)

    assert resp.status_code == 404
    # The ownership 404, not a missing-route 404.
    assert resp.json()["detail"] == "player not found"


def test_create_missing_upload_length_400_and_oversize_413(client, auth_headers):
    player_id = make_player(client, auth_headers)

    no_length = client.post(
        "/api/v1/uploads",
        headers={**auth_headers, **TUS, "Upload-Metadata": _metadata(
            filename="clip.mp4", playerId=player_id, sessionId="s", mode="footwork"
        )},
    )
    assert no_length.status_code == 400

    garbage = client.post(
        "/api/v1/uploads",
        headers={**auth_headers, **TUS, "Upload-Length": "not-a-number"},
    )
    assert garbage.status_code == 400

    oversize = create_upload(
        client, auth_headers, player_id, length=4 * 1024**3 + 1
    )
    assert oversize.status_code == 413


def test_create_missing_tus_resumable_header_412(client, auth_headers):
    player_id = make_player(client, auth_headers)

    resp = client.post(
        "/api/v1/uploads",
        headers={
            **auth_headers,
            "Upload-Length": "64",
            "Upload-Metadata": _metadata(
                filename="clip.mp4",
                playerId=player_id,
                sessionId="s",
                mode="footwork",
            ),
        },
    )

    assert resp.status_code == 412


# --- Slice 2: HEAD resume probe ---


def test_head_reports_current_offset(client, auth_headers):
    player_id = make_player(client, auth_headers)
    location = create_upload(client, auth_headers, player_id).headers["Location"]

    resp = client.head(location, headers={**auth_headers, **TUS})

    assert resp.status_code == 200
    assert resp.headers["Upload-Offset"] == "0"
    assert resp.headers["Upload-Length"] == "64"
    assert resp.headers["Cache-Control"] == "no-store"
    assert resp.headers["Tus-Resumable"] == "1.0.0"


def test_head_unknown_id_404_and_foreign_account_404(client, auth_headers):
    player_id = make_player(client, auth_headers)
    location = create_upload(client, auth_headers, player_id).headers["Location"]

    unknown = client.head(
        "/api/v1/uploads/no-such-id", headers={**auth_headers, **TUS}
    )
    assert unknown.status_code == 404

    other_headers = register_and_login(client, email="probe@example.com")
    foreign = client.head(location, headers={**other_headers, **TUS})
    # The ownership 404, not a missing-route 404 (HEAD carries no body,
    # so the marker is the tus header set by the real handler's exception).
    assert foreign.status_code == 404
    assert foreign.headers.get("Tus-Resumable") == "1.0.0"


def test_head_complete_or_aborted_410(client, auth_headers, settings):
    player_id = make_player(client, auth_headers)
    location = create_upload(client, auth_headers, player_id).headers["Location"]
    upload_id = location.rsplit("/", 1)[1]

    for status in ("complete", "aborted"):
        with get_conn(settings) as conn:
            conn.execute(
                "UPDATE uploads SET status = ? WHERE id = ?", (status, upload_id)
            )
        resp = client.head(location, headers={**auth_headers, **TUS})
        assert resp.status_code == 410, status
