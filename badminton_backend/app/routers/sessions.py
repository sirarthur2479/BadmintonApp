import sqlite3
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request

from ..database import get_conn
from ..deps import require_player
from ..models import Session

# Every route inherits the ownership check: an unknown or foreign playerId
# 404s before any handler runs.
router = APIRouter(
    prefix="/players/{player_id}/sessions",
    tags=["sessions"],
    dependencies=[Depends(require_player)],
)

_COLS = (
    "id, date, durationMinutes, drills, intensity, notes, photoPath, "
    "sessionGoal, goalAchievementScore, playerRemarks, coachRemarks, "
    "reflectionAnswersJson"
)


def _to_session(row: sqlite3.Row) -> Session:
    return Session(**dict(row))


def _values(s: Session, player_id: str) -> tuple:
    return (
        s.id,
        player_id,
        s.date,
        s.durationMinutes,
        s.drills,
        s.intensity,
        s.notes,
        s.photoPath,
        s.sessionGoal,
        s.goalAchievementScore,
        s.playerRemarks,
        s.coachRemarks,
        s.reflectionAnswersJson,
    )


_INSERT = (
    "INSERT OR {mode} INTO sessions (id, playerId, date, durationMinutes, "
    "drills, intensity, notes, photoPath, sessionGoal, goalAchievementScore, "
    "playerRemarks, coachRemarks, reflectionAnswersJson) "
    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
)


@router.get("", response_model=list[Session])
def list_sessions(player_id: str, request: Request) -> list[Session]:
    with get_conn(request.app.state.settings) as conn:
        rows = conn.execute(
            f"SELECT {_COLS} FROM sessions WHERE playerId = ? ORDER BY date DESC",
            (player_id,),
        ).fetchall()
    return [_to_session(r) for r in rows]


@router.get("/any")
def any_sessions(player_id: str, request: Request) -> dict:
    with get_conn(request.app.state.settings) as conn:
        count = conn.execute(
            "SELECT COUNT(*) FROM sessions WHERE playerId = ?", (player_id,)
        ).fetchone()[0]
    return {"any": count > 0}


@router.post("", status_code=201, response_model=Session)
def upsert_session(player_id: str, session: Session, request: Request) -> Session:
    with get_conn(request.app.state.settings) as conn:
        conn.execute(_INSERT.format(mode="REPLACE"), _values(session, player_id))
    return session


@router.post("/batch", status_code=201)
def batch_insert(player_id: str, sessions: list[Session], request: Request) -> dict:
    with get_conn(request.app.state.settings) as conn:
        conn.executemany(
            _INSERT.format(mode="IGNORE"),
            [_values(s, player_id) for s in sessions],
        )
    return {"received": len(sessions)}


@router.put("/{session_id}", response_model=Session)
def update_session(
    player_id: str, session_id: str, session: Session, request: Request
) -> Session:
    with get_conn(request.app.state.settings) as conn:
        cur = conn.execute(
            "UPDATE sessions SET date = ?, durationMinutes = ?, drills = ?, "
            "intensity = ?, notes = ?, photoPath = ?, sessionGoal = ?, "
            "goalAchievementScore = ?, playerRemarks = ?, coachRemarks = ?, "
            "reflectionAnswersJson = ? WHERE id = ? AND playerId = ?",
            (
                session.date,
                session.durationMinutes,
                session.drills,
                session.intensity,
                session.notes,
                session.photoPath,
                session.sessionGoal,
                session.goalAchievementScore,
                session.playerRemarks,
                session.coachRemarks,
                session.reflectionAnswersJson,
                session_id,
                player_id,
            ),
        )
        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="session not found")
    return session.model_copy(update={"id": session_id})


@router.delete("/{session_id}", status_code=204)
def delete_session(player_id: str, session_id: str, request: Request) -> None:
    with get_conn(request.app.state.settings) as conn:
        conn.execute(
            "DELETE FROM sessions WHERE id = ? AND playerId = ?",
            (session_id, player_id),
        )