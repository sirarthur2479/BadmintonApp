"""Job status polling routes (TASK-029).

Ownership is scoped through the job's player's account (jobs have no
accountId column; the join is the source of truth). Foreign ids are a
non-leaking 404, matching require_player.
"""

import sqlite3
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request

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
