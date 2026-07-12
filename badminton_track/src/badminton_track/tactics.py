"""Tactics brief (pool #10): local-LLM gameplan from pre-worded opponent
facts.

Same contract as the coach narrative (module 4): every statistic is computed
and worded client-side (the Flutter facts builder) — the model only narrates
and may never invent numbers. Same privacy guards: `-cloud` tags are refused
before any client is built, and every failure degrades (the app falls back
to its metrics-only brief).
"""

import logging
from typing import TYPE_CHECKING

from pydantic import BaseModel, Field

from .errors import ExtrasMissingError

if TYPE_CHECKING:
    from .config import CoachConfig

log = logging.getLogger(__name__)

TACTICS_PROMPT = """\
You are an encouraging badminton coach preparing a 12-year-old player for a
rematch. You will receive a list of measured facts about a specific opponent.
Write a tactical brief following ALL of these rules:

- Base every claim on the facts given. NEVER invent numbers. Only restate
  figures that appear in the facts.
- Give 2 to 4 concrete tactical recommendations the player can actually do
  (serves, shot choices, rally plans) — phrased positively.
- Give 2 or 3 named practice drills that prepare those tactics.
- Growth-mindset framing: the opponent's strengths are puzzles to solve,
  not threats.
- NEVER comment on anyone's body, weight, height, or appearance — only
  play patterns and technique.
- Write at a 12-year-old reading level: short sentences, no jargon without
  a quick explanation.
"""


class TacticsBrief(BaseModel):
    summary: str
    # Schema-enforced: guardrails as constraints, not hopes.
    recommendations: list[str] = Field(min_length=2, max_length=4)
    drills: list[str] = Field(min_length=2, max_length=3)


def generate_tactics_brief(
    opponent: str,
    facts: list[str],
    cfg: "CoachConfig",
    extra_instruction: str | None = None,
) -> TacticsBrief | None:
    """One schema-constrained chat call; None when Ollama is unreachable.

    Raises ValueError for `-cloud` tags BEFORE any client is built — data
    about a minor never transits the internet.
    """
    if cfg.model_tag.endswith("-cloud"):
        raise ValueError(
            f"model tag '{cfg.model_tag}' is an Ollama cloud model — "
            f"cloud inference is forbidden for this tool"
        )
    try:
        import ollama
    except ImportError as exc:
        raise ExtrasMissingError(
            "the tactics brief needs the ollama package — "
            'install with: pip install "badminton-track[coach]"'
        ) from exc

    client = ollama.Client(host=cfg.ollama_host)
    user_content = f"Opponent: {opponent}\n\nMeasured facts:\n" + "\n".join(
        f"- {fact}" for fact in facts
    )
    if extra_instruction:
        user_content += "\n\n" + extra_instruction
    try:
        resp = client.chat(
            model=cfg.model_tag,
            messages=[
                {"role": "system", "content": TACTICS_PROMPT},  # stable prefix
                {"role": "user", "content": user_content},
            ],
            format=TacticsBrief.model_json_schema(),
            options={"temperature": 0.4, "num_ctx": 8192},
            think=False,
        )
        return TacticsBrief.model_validate_json(resp.message.content)
    except ConnectionError:
        log.warning("Ollama not running at %s; no tactics brief", cfg.ollama_host)
        return None
    except ollama.ResponseError as exc:
        if getattr(exc, "status_code", None) == 404:
            log.warning(
                "model %s not available — run: ollama pull %s",
                cfg.model_tag,
                cfg.model_tag,
            )
        else:
            log.warning("Ollama error %s", exc)
        return None


# Same body-commentary screen as the coach narrative.
_BANNED_TERMS = [
    "weight",
    "fat",
    "skinny",
    "chubby",
    "thin",
    "taller",
    "shorter",
    "height",
    "body shape",
]


def lint_brief(brief: TacticsBrief) -> list[str]:
    """Deterministic post-generation checks; empty list means clean."""
    violations: list[str] = []
    for text in [brief.summary, *brief.recommendations, *brief.drills]:
        lowered = text.lower()
        for term in _BANNED_TERMS:
            if term in lowered:
                violations.append(
                    f'banned body-commentary term "{term}" in: "{text[:80]}"'
                )
    return violations


def render_tactics_markdown(
    brief: TacticsBrief, opponent: str, facts: list[str]
) -> str:
    lines = [
        f"# Tactical brief — {opponent}",
        "",
        brief.summary,
        "",
        "## Game plan",
        "",
        *[f"{i + 1}. {rec}" for i, rec in enumerate(brief.recommendations)],
        "",
        "## Drills to practise",
        "",
        *[f"- {drill}" for drill in brief.drills],
        "",
        "### The numbers behind this",
        "",
        *[f"- {fact}" for fact in facts],
        "",
    ]
    return "\n".join(lines)


def produce_tactics_brief(
    opponent: str, facts: list[str], cfg: "CoachConfig"
) -> str | None:
    """Narrative markdown with one lint-retry; None when the LLM can't help
    (the caller falls back to its deterministic metrics-only brief)."""
    brief = generate_tactics_brief(opponent, facts, cfg)
    if brief is None:
        return None
    violations = lint_brief(brief)
    if not violations:
        return render_tactics_markdown(brief, opponent, facts)
    retry = generate_tactics_brief(
        opponent,
        facts,
        cfg,
        extra_instruction=(
            "Your previous draft broke these rules: "
            + "; ".join(violations)
            + ". Rewrite the brief and follow every rule."
        ),
    )
    if retry is not None and not lint_brief(retry):
        return render_tactics_markdown(retry, opponent, facts)
    log.warning("tactics brief failed lint twice; no narrative brief")
    return None
