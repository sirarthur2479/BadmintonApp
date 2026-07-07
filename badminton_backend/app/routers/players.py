import sqlite3
from typing import Annotated

from fastapi import APIRouter, Depends, Request

from ..database import get_conn
from ..deps import current_account, require_player
from ..models import Player

router = APIRouter(prefix="/players", tags=["players"])

_FIELDS = (
    "id, name, age, club, playingStyle, preferredGrip, "
    "shortTermGoal, longTermGoal, photoPath"
)


def _to_player(row: sqlite3.Row) -> Player:
    return Player(**{key: row[key] for key in row.keys() if key != "accountId"})


@router.get("", response_model=list[Player])
def list_players(
    request: Request,
    account: Annotated[sqlite3.Row, Depends(current_account)],
) -> list[Player]:
    with get_conn(request.app.state.settings) as conn:
        rows = conn.execute(
            f"SELECT {_FIELDS} FROM players WHERE accountId = ? ORDER BY name",
            (account["id"],),
        ).fetchall()
    return [_to_player(r) for r in rows]


@router.post("", status_code=201, response_model=Player)
def create_player(
    player: Player,
    request: Request,
    account: Annotated[sqlite3.Row, Depends(current_account)],
) -> Player:
    with get_conn(request.app.state.settings) as conn:
        conn.execute(
            "INSERT INTO players (id, accountId, name, age, club, playingStyle, "
            "preferredGrip, shortTermGoal, longTermGoal, photoPath) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                player.id,
                account["id"],
                player.name,
                player.age,
                player.club,
                player.playingStyle,
                player.preferredGrip,
                player.shortTermGoal,
                player.longTermGoal,
                player.photoPath,
            ),
        )
    return player


@router.put("/{player_id}", response_model=Player)
def update_player(
    player: Player,
    request: Request,
    existing: Annotated[sqlite3.Row, Depends(require_player)],
) -> Player:
    with get_conn(request.app.state.settings) as conn:
        conn.execute(
            "UPDATE players SET name = ?, age = ?, club = ?, playingStyle = ?, "
            "preferredGrip = ?, shortTermGoal = ?, longTermGoal = ?, "
            "photoPath = ? WHERE id = ?",
            (
                player.name,
                player.age,
                player.club,
                player.playingStyle,
                player.preferredGrip,
                player.shortTermGoal,
                player.longTermGoal,
                player.photoPath,
                existing["id"],
            ),
        )
    return player.model_copy(update={"id": existing["id"]})


@router.delete("/{player_id}", status_code=204)
def delete_player(
    request: Request,
    existing: Annotated[sqlite3.Row, Depends(require_player)],
) -> None:
    # sessions/tournaments(+matches)/custom_tags all cascade via FK.
    with get_conn(request.app.state.settings) as conn:
        conn.execute("DELETE FROM players WHERE id = ?", (existing["id"],))