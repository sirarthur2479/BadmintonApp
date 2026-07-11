"""Job status polling routes (TASK-029).

Ownership is scoped through the job's player's account (jobs have no
accountId column; the join is the source of truth). Foreign ids are a
non-leaking 404, matching require_player.
"""

import sqlite3
from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import FileResponse

from ..database import get_conn
from ..deps import current_account

router = APIRouter(prefix="/jobs", tags=["jobs"])

_COLS = (
    "jobs.id, jobs.playerId, jobs.sessionId, jobs.mode, jobs.status,"
    " jobs.reportPath, jobs.courtMapPath, jobs.errorMessage, jobs.createdAt,"
    " jobs.startedAt, jobs.finishedAt"
)


@router.get("/{job_id}")
def get_job(
    job_id: str,
    request: Request,
    account: Annotated[sqlite3.Row, Depends(current_account)],
) -> dict:
    with get_conn(request.app.state.settings) as conn:
        row = conn.execute(
            f"SELECT {_COLS} FROM jobs"
            " JOIN players ON players.id = jobs.playerId"
            " WHERE jobs.id = ? AND players.accountId = ?",
            (job_id, account["id"]),
        ).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="job not found")
    return dict(row)


@router.get("")
def list_jobs(
    sessionId: str,
    request: Request,
    account: Annotated[sqlite3.Row, Depends(current_account)],
) -> list[dict]:
    with get_conn(request.app.state.settings) as conn:
        rows = conn.execute(
            f"SELECT {_COLS} FROM jobs"
            " JOIN players ON players.id = jobs.playerId"
            " WHERE jobs.sessionId = ? AND players.accountId = ?"
            " ORDER BY jobs.createdAt DESC",
            (sessionId, account["id"]),
        ).fetchall()
    return [dict(r) for r in rows]


def _artifact_response(row: dict, column: str) -> FileResponse:
    """404 unless the job is done AND the artifact exists — a job without a
    court map (biomech mode) 404s the same as a missing job, leaking nothing."""
    path = row.get(column)
    if row["status"] != "done" or not path or not Path(path).exists():
        raise HTTPException(status_code=404, detail="artifact not available")
    return FileResponse(path)


@router.get("/{job_id}/report")
def download_report(
    job_id: str,
    request: Request,
    account: Annotated[sqlite3.Row, Depends(current_account)],
) -> FileResponse:
    return _artifact_response(get_job(job_id, request, account), "reportPath")


@router.get("/{job_id}/court-map")
def download_court_map(
    job_id: str,
    request: Request,
    account: Annotated[sqlite3.Row, Depends(current_account)],
) -> FileResponse:
    return _artifact_response(get_job(job_id, request, account), "courtMapPath")
