import sqlite3
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request

from ..database import get_conn
from ..deps import require_player
from ..models import Match, TournamentIn, TournamentOut

router = APIRouter(
    prefix="/players/{player_id}/tournaments",
    tags=["tournaments"],
    dependencies=[Depends(require_player)],
)


def _own_tournament(
    conn: sqlite3.Connection, tournament_id: str, player_id: str
) -> sqlite3.Row:
    """The tournament row IF it belongs to this player; else 404."""
    row = conn.execute(
        "SELECT * FROM tournaments WHERE id = ? AND playerId = ?",
        (tournament_id, player_id),
    ).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="tournament not found")
    return row


@router.get("", response_model=list[TournamentOut])
def list_tournaments(player_id: str, request: Request) -> list[TournamentOut]:
    with get_conn(request.app.state.settings) as conn:
        t_rows = conn.execute(
            "SELECT id, name, date, location, format FROM tournaments "
            "WHERE playerId = ? ORDER BY date DESC",
            (player_id,),
        ).fetchall()
        out = []
        for t in t_rows:
            m_rows = conn.execute(
                "SELECT id, tournamentId, opponent, scores, isWin, notes "
                "FROM matches WHERE tournamentId = ?",
                (t["id"],),
            ).fetchall()
            out.append(
                TournamentOut(
                    **dict(t), matches=[Match(**dict(m)) for m in m_rows]
                )
            )
    return out


@router.post("", status_code=201, response_model=TournamentIn)
def create_tournament(
    player_id: str, tournament: TournamentIn, request: Request
) -> TournamentIn:
    with get_conn(request.app.state.settings) as conn:
        conn.execute(
            "INSERT OR REPLACE INTO tournaments (id, playerId, name, date, "
            "location, format) VALUES (?, ?, ?, ?, ?, ?)",
            (
                tournament.id,
                player_id,
                tournament.name,
                tournament.date,
                tournament.location,
                tournament.format,
            ),
        )
    return tournament


@router.delete("/{tournament_id}", status_code=204)
def delete_tournament(
    player_id: str, tournament_id: str, request: Request
) -> None:
    with get_conn(request.app.state.settings) as conn:
        _own_tournament(conn, tournament_id, player_id)
        # Matches cascade via FK.
        conn.execute("DELETE FROM tournaments WHERE id = ?", (tournament_id,))


@router.post("/{tournament_id}/matches", status_code=201, response_model=Match)
def add_match(
    player_id: str, tournament_id: str, match: Match, request: Request
) -> Match:
    with get_conn(request.app.state.settings) as conn:
        _own_tournament(conn, tournament_id, player_id)
        conn.execute(
            "INSERT OR REPLACE INTO matches (id, tournamentId, opponent, "
            "scores, isWin, notes) VALUES (?, ?, ?, ?, ?, ?)",
            (
                match.id,
                tournament_id,
                match.opponent,
                match.scores,
                match.isWin,
                match.notes,
            ),
        )
    return match


@router.delete("/{tournament_id}/matches/{match_id}", status_code=204)
def delete_match(
    player_id: str, tournament_id: str, match_id: str, request: Request
) -> None:
    with get_conn(request.app.state.settings) as conn:
        _own_tournament(conn, tournament_id, player_id)
        conn.execute(
            "DELETE FROM matches WHERE id = ? AND tournamentId = ?",
            (match_id, tournament_id),
        )