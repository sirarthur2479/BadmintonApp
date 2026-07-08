"""tus 1.0.0 Core + Creation subset (research/resumable-upload.md).

Hand-rolled on purpose: byte-offset bookkeeping is integrity-critical for
1-2 GB video files, so this router owns the whole protocol surface and its
tests rather than depending on a stale wrapper. `sessionId` is an opaque
correlation key from the offline-first phone, not a sessions-table FK.
"""

import base64
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
