"""tus 1.0.0 Core + Creation subset (research/resumable-upload.md).

Hand-rolled on purpose: byte-offset bookkeeping is integrity-critical for
1-2 GB video files, so this router owns the whole protocol surface and its
tests rather than depending on a stale wrapper. `sessionId` is an opaque
correlation key from the offline-first phone, not a sessions-table FK.
"""

import asyncio
import base64
import os
import sqlite3
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, Response

from ..database import get_conn
from ..deps import current_account

router = APIRouter(prefix="/uploads", tags=["uploads"])

TUS_VERSION = "1.0.0"
TUS_MAX_SIZE = 4 * 1024**3  # 4 GiB, comfortably above a 10-min 1080p60 clip

_TUS_HEADERS = {"Tus-Resumable": TUS_VERSION}

# One lock per in-flight upload id: overlapping PATCHes must not race the
# offset check/write/update sequence. Dropped when the upload finishes.
_locks: dict[str, asyncio.Lock] = {}


def _lock_for(upload_id: str) -> asyncio.Lock:
    return _locks.setdefault(upload_id, asyncio.Lock())


def on_upload_complete(row: sqlite3.Row, request: Request) -> None:
    """Called once when an upload's final byte lands. No-op seam — TASK-029
    replaces the body with the analysis-job enqueue."""


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _require_tus_resumable(request: Request) -> None:
    """tus precondition: creation and data-transfer requests must declare
    the protocol version (412 per spec, so old clients fail loudly)."""
    if request.headers.get("Tus-Resumable") != TUS_VERSION:
        raise HTTPException(status_code=412, detail="Tus-Resumable 1.0.0 required")


def _parse_metadata(header: str) -> dict[str, str]:
    """Upload-Metadata: comma-separated `key base64(value)` pairs."""
    metadata: dict[str, str] = {}
    for pair in header.split(","):
        pair = pair.strip()
        if not pair:
            continue
        key, _, encoded = pair.partition(" ")
        try:
            metadata[key] = base64.b64decode(encoded, validate=True).decode()
        except Exception:
            raise HTTPException(
                status_code=400, detail=f"invalid Upload-Metadata value for '{key}'"
            )
    return metadata


def _require_upload(
    upload_id: str, settings, account: sqlite3.Row, *, live_only: bool = True
) -> sqlite3.Row:
    """The upload row IF it belongs to the caller's account; else 404
    (non-leaking, same posture as require_player). 410 for finished rows
    when `live_only` — tus says a gone upload must not be probed/patched."""
    with get_conn(settings) as conn:
        row = conn.execute(
            "SELECT * FROM uploads WHERE id = ? AND accountId = ?",
            (upload_id, account["id"]),
        ).fetchone()
    if row is None:
        raise HTTPException(
            status_code=404, detail="upload not found", headers=_TUS_HEADERS
        )
    if live_only and row["status"] != "in_progress":
        raise HTTPException(status_code=410, detail="upload gone", headers=_TUS_HEADERS)
    return row


@router.options("")
def tus_discovery(
    account: Annotated[sqlite3.Row, Depends(current_account)],
) -> Response:
    return Response(
        status_code=204,
        headers={
            **_TUS_HEADERS,
            "Tus-Version": TUS_VERSION,
            "Tus-Extension": "creation",
            "Tus-Max-Size": str(TUS_MAX_SIZE),
        },
    )


@router.post("")
def create_upload(
    request: Request,
    account: Annotated[sqlite3.Row, Depends(current_account)],
) -> Response:
    _require_tus_resumable(request)
    settings = request.app.state.settings

    raw_length = request.headers.get("Upload-Length")
    if raw_length is None or not raw_length.isdigit():
        raise HTTPException(status_code=400, detail="Upload-Length header required")
    total_bytes = int(raw_length)
    if total_bytes > TUS_MAX_SIZE:
        raise HTTPException(status_code=413, detail="Upload-Length over Tus-Max-Size")

    metadata = _parse_metadata(request.headers.get("Upload-Metadata", ""))
    missing = {"filename", "playerId", "sessionId", "mode"} - metadata.keys()
    if missing:
        raise HTTPException(
            status_code=400,
            detail=f"Upload-Metadata missing keys: {', '.join(sorted(missing))}",
        )

    with get_conn(settings) as conn:
        player = conn.execute(
            "SELECT id FROM players WHERE id = ? AND accountId = ?",
            (metadata["playerId"], account["id"]),
        ).fetchone()
    if player is None:
        # Same non-leaking 404 as require_player.
        raise HTTPException(status_code=404, detail="player not found")

    upload_id = str(uuid.uuid4())
    upload_dir = Path(settings.upload_dir)
    upload_dir.mkdir(parents=True, exist_ok=True)
    storage_path = upload_dir / upload_id
    storage_path.touch()

    now = _now()
    with get_conn(settings) as conn:
        conn.execute(
            "INSERT INTO uploads (id, accountId, playerId, sessionId, mode,"
            " filename, total_bytes, storage_path, created_at, updated_at)"
            " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                upload_id,
                account["id"],
                metadata["playerId"],
                metadata["sessionId"],
                metadata["mode"],
                metadata["filename"],
                total_bytes,
                str(storage_path),
                now,
                now,
            ),
        )

    return Response(
        status_code=201,
        headers={**_TUS_HEADERS, "Location": f"/api/v1/uploads/{upload_id}"},
    )


@router.head("/{upload_id}")
def probe_upload(
    upload_id: str,
    request: Request,
    account: Annotated[sqlite3.Row, Depends(current_account)],
) -> Response:
    row = _require_upload(upload_id, request.app.state.settings, account)
    return Response(
        status_code=200,
        headers={
            **_TUS_HEADERS,
            "Upload-Offset": str(row["offset_bytes"]),
            "Upload-Length": str(row["total_bytes"]),
            "Cache-Control": "no-store",
        },
    )


@router.patch("/{upload_id}")
async def append_chunk(
    upload_id: str,
    request: Request,
    account: Annotated[sqlite3.Row, Depends(current_account)],
) -> Response:
    _require_tus_resumable(request)
    if request.headers.get("Content-Type") != "application/offset+octet-stream":
        raise HTTPException(
            status_code=415,
            detail="Content-Type must be application/offset+octet-stream",
            headers=_TUS_HEADERS,
        )
    settings = request.app.state.settings

    async with _lock_for(upload_id):
        # Row fetch and offset check live under the lock: a concurrent PATCH
        # that lost the race must see the advanced offset and get the 409.
        row = _require_upload(upload_id, settings, account)

        claimed = request.headers.get("Upload-Offset", "")
        if not claimed.isdigit() or int(claimed) != row["offset_bytes"]:
            # The client must HEAD-probe and retry from the server's offset.
            raise HTTPException(
                status_code=409, detail="Upload-Offset mismatch", headers=_TUS_HEADERS
            )
        offset = int(claimed)

        # Stream to disk — a chunk may be hundreds of MB; never buffer it whole.
        written = 0
        with open(row["storage_path"], "r+b") as f:
            f.seek(offset)
            async for part in request.stream():
                f.write(part)
                written += len(part)
            f.flush()
            os.fsync(f.fileno())

        # Only after the bytes are durably on disk does the offset advance —
        # SQLite is the resumption source of truth.
        new_offset = offset + written
        completed = new_offset == row["total_bytes"]
        with get_conn(settings) as conn:
            conn.execute(
                "UPDATE uploads SET offset_bytes = ?, status = ?, updated_at = ?"
                " WHERE id = ?",
                (
                    new_offset,
                    "complete" if completed else "in_progress",
                    _now(),
                    upload_id,
                ),
            )
            if completed:
                row = conn.execute(
                    "SELECT * FROM uploads WHERE id = ?", (upload_id,)
                ).fetchone()

    if completed:
        _locks.pop(upload_id, None)
        on_upload_complete(row, request)

    return Response(
        status_code=204,
        headers={**_TUS_HEADERS, "Upload-Offset": str(new_offset)},
    )
