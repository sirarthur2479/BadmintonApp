import sqlite3

from fastapi import APIRouter, Depends, HTTPException, Request

from ..database import get_conn
from ..deps import require_player
from ..models import PointRecord

# Nested under a match log; every route inherits the player ownership check
# (unknown/foreign playerId 404s before any handler) and re-checks that the
# match log belongs to this player, so a foreign log_id is equally invisible.
router = APIRouter(
    prefix="/players/{player_id}/match-logs/{log_id}/points",
    tags=["point-records"],
    dependencies=[Depends(require_player)],
)

_COLS = (
    "id, matchLogId, game, indexInGame, server, winner, playerScore, "
    "opponentScore, rallyLength, endingType, endingShot, endingZone, "
    "endingSide, videoTimestampMs, shots"
)

_INSERT = (
    "INSERT OR REPLACE INTO point_records (id, matchLogId, game, indexInGame, "
    "server, winner, playerScore, opponentScore, rallyLength, endingType, "
    "endingShot, endingZone, endingSide, videoTimestampMs, shots) "
    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
)


def _own_match_log(conn: sqlite3.Connection, log_id: str, player_id: str) -> None:
    """404 unless the match log exists AND belongs to this player."""
    row = conn.execute(
        "SELECT id FROM match_logs WHERE id = ? AND playerId = ?",
        (log_id, player_id),
    ).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="match log not found")


def _values(point: PointRecord, log_id: str) -> tuple:
    return (
        point.id,
        log_id,
        point.game,
        point.indexInGame,
        point.server,
        point.winner,
        point.playerScore,
        point.opponentScore,
        point.rallyLength,
        point.endingType,
        point.endingShot,
        point.endingZone,
        point.endingSide,
        point.videoTimestampMs,
        point.shots,
    )


@router.get("", response_model=list[PointRecord])
def list_points(player_id: str, log_id: str, request: Request) -> list[PointRecord]:
    with get_conn(request.app.state.settings) as conn:
        _own_match_log(conn, log_id, player_id)
        rows = conn.execute(
            f"SELECT {_COLS} FROM point_records WHERE matchLogId = ? "
            "ORDER BY game, indexInGame",
            (log_id,),
        ).fetchall()
    return [PointRecord(**dict(r)) for r in rows]


@router.post("", status_code=201, response_model=PointRecord)
def upsert_point(
    player_id: str, log_id: str, point: PointRecord, request: Request
) -> PointRecord:
    with get_conn(request.app.state.settings) as conn:
        _own_match_log(conn, log_id, player_id)
        conn.execute(_INSERT, _values(point, log_id))
    return point.model_copy(update={"matchLogId": log_id})
