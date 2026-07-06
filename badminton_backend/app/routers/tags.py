from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, Field

from ..database import get_conn
from ..deps import require_player

router = APIRouter(
    prefix="/players/{player_id}/tags",
    tags=["tags"],
    dependencies=[Depends(require_player)],
)


class TagIn(BaseModel):
    name: str = Field(min_length=1)


@router.get("", response_model=list[str])
def list_tags(player_id: str, request: Request) -> list[str]:
    with get_conn(request.app.state.settings) as conn:
        rows = conn.execute(
            "SELECT name FROM custom_tags WHERE playerId = ? ORDER BY name",
            (player_id,),
        ).fetchall()
    return [r["name"] for r in rows]


@router.post("", status_code=201)
def add_tag(player_id: str, tag: TagIn, request: Request) -> dict:
    with get_conn(request.app.state.settings) as conn:
        conn.execute(
            "INSERT OR IGNORE INTO custom_tags (playerId, name) VALUES (?, ?)",
            (player_id, tag.name),
        )
    return {"name": tag.name}


@router.delete("/{name}", status_code=204)
def delete_tag(player_id: str, name: str, request: Request) -> None:
    with get_conn(request.app.state.settings) as conn:
        conn.execute(
            "DELETE FROM custom_tags WHERE playerId = ? AND name = ?",
            (player_id, name),
        )