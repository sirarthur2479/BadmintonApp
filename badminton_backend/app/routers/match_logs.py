import sqlite3

from fastapi import APIRouter, Depends, HTTPException, Request

from ..database import get_conn
from ..deps import require_player
from ..models import MatchLog

# Every route inherits the ownership check: an unknown or foreign playerId
# 404s before any handler runs.
router = APIRouter(
    prefix="/players/{player_id}/match-logs",
    tags=["match-logs"],
    dependencies=[Depends(require_player)],
)

_COLS = (
    "id, date, opponent, eventContext, scores, isWin, gameplan, "
    "readinessScore, performanceNotes, keyMoments, videoRef"
)


def _to_match_log(row: sqlite3.Row) -> MatchLog:
    return MatchLog(**dict(row))


def _values(log: MatchLog, player_id: str) -> tuple:
    return (
        log.id,
        player_id,
        log.date,
        log.opponent,
        log.eventContext,
        log.scores,
        log.isWin,
        log.gameplan,
        log.readinessScore,
        log.performanceNotes,
        log.keyMoments,
        log.videoRef,
    )


_INSERT = (
    "INSERT OR {mode} INTO match_logs (id, playerId, date, opponent, "
    "eventContext, scores, isWin, gameplan, readinessScore, "
    "performanceNotes, keyMoments, videoRef) "
    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
)


@router.get("", response_model=list[MatchLog])
def list_match_logs(player_id: str, request: Request) -> list[MatchLog]:
    with get_conn(request.app.state.settings) as conn:
        rows = conn.execute(
            f"SELECT {_COLS} FROM match_logs WHERE playerId = ? ORDER BY date DESC",
            (player_id,),
        ).fetchall()
    return [_to_match_log(r) for r in rows]


@router.get("/any")
def any_match_logs(player_id: str, request: Request) -> dict:
    with get_conn(request.app.state.settings) as conn:
        count = conn.execute(
            "SELECT COUNT(*) FROM match_logs WHERE playerId = ?", (player_id,)
        ).fetchone()[0]
    return {"any": count > 0}


@router.post("", status_code=201, response_model=MatchLog)
def upsert_match_log(player_id: str, log: MatchLog, request: Request) -> MatchLog:
    with get_conn(request.app.state.settings) as conn:
        conn.execute(_INSERT.format(mode="REPLACE"), _values(log, player_id))
    return log


@router.post("/batch", status_code=201)
def batch_insert(player_id: str, logs: list[MatchLog], request: Request) -> dict:
    with get_conn(request.app.state.settings) as conn:
        conn.executemany(
            _INSERT.format(mode="IGNORE"),
            [_values(log, player_id) for log in logs],
        )
    return {"received": len(logs)}


@router.put("/{log_id}", response_model=MatchLog)
def update_match_log(
    player_id: str, log_id: str, log: MatchLog, request: Request
) -> MatchLog:
    with get_conn(request.app.state.settings) as conn:
        cur = conn.execute(
            "UPDATE match_logs SET date = ?, opponent = ?, eventContext = ?, "
            "scores = ?, isWin = ?, gameplan = ?, readinessScore = ?, "
            "performanceNotes = ?, keyMoments = ?, videoRef = ? "
            "WHERE id = ? AND playerId = ?",
            (
                log.date,
                log.opponent,
                log.eventContext,
                log.scores,
                log.isWin,
                log.gameplan,
                log.readinessScore,
                log.performanceNotes,
                log.keyMoments,
                log.videoRef,
                log_id,
                player_id,
            ),
        )
        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="match log not found")
    return log.model_copy(update={"id": log_id})


@router.delete("/{log_id}", status_code=204)
def delete_match_log(player_id: str, log_id: str, request: Request) -> None:
    with get_conn(request.app.state.settings) as conn:
        conn.execute(
            "DELETE FROM match_logs WHERE id = ? AND playerId = ?",
            (log_id, player_id),
        )
