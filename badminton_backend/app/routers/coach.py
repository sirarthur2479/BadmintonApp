"""POST /coach/opponent-brief: the LLM half of the opponent profile.

The client computes and pre-words every statistic (the TASK-050 facts
contract) and sends the fact strings verbatim; this endpoint only runs the
guarded badminton_track tactics engine against the local Ollama and returns
Markdown. Every failure is a 503 with an actionable message — the app falls
back to its deterministic metrics-only brief.
"""

import logging
import os
from pathlib import Path
from typing import Callable

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field

from ..deps import current_account

log = logging.getLogger(__name__)

router = APIRouter(
    prefix="/coach",
    tags=["coach"],
    dependencies=[Depends(current_account)],
)

# str | None return: None means "LLM couldn't help" (Ollama down / lint
# failed twice) — distinct from raising, which means the setup is broken.
TacticsEngine = Callable[[str, list[str]], str | None]


def real_tactics_engine(opponent: str, facts: list[str]) -> str | None:
    """The only place that imports badminton_track's tactics module —
    lazily, mirroring jobs.real_pipeline_runner."""
    try:
        from badminton_track.config import load_config
        from badminton_track.tactics import produce_tactics_brief
    except ImportError as exc:
        raise RuntimeError(
            "badminton_track is not installed in the server environment — "
            "install it next to the backend: pip install -e ../badminton_track"
        ) from exc

    cfg_path = os.environ.get("TRACK_CONFIG")
    cfg = load_config(Path(cfg_path) if cfg_path else None)
    return produce_tactics_brief(opponent, facts, cfg.coach)


class BriefRequest(BaseModel):
    opponent: str = Field(min_length=1)
    facts: list[str] = Field(min_length=1)


@router.post("/opponent-brief")
def opponent_brief(body: BriefRequest, request: Request) -> dict:
    engine: TacticsEngine = getattr(
        request.app.state, "tactics_engine", real_tactics_engine
    )
    try:
        markdown = engine(body.opponent, body.facts)
    except (RuntimeError, ValueError) as exc:
        # ExtrasMissing/bad-config style failures: message is actionable.
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    if markdown is None:
        raise HTTPException(
            status_code=503,
            detail=(
                "The tactics brief needs the local LLM: start Ollama on the "
                "server (and pull the configured model) then try again."
            ),
        )
    return {"markdown": markdown}
