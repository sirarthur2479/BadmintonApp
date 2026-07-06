"""Module 4 — local-LLM coach narrative.

The LLM never sees per-frame data and never does arithmetic: all statistics
are computed here (pandas/numpy) and handed over as a compact summary whose
anomalies are already worded as plain-English facts. The model only narrates.
"""

import json
import logging
import math
from typing import TYPE_CHECKING

import pandas as pd
from pydantic import BaseModel, Field

from . import metrics
from .errors import ExtrasMissingError

if TYPE_CHECKING:
    from .config import CoachConfig

log = logging.getLogger(__name__)

PERSONA_PROMPT = """\
You are an encouraging badminton coach writing for a 12-year-old player.
You will receive a JSON summary of measured training facts. Write the report
following ALL of these rules:

- Growth-mindset framing: praise effort and progress, treat mistakes as
  information, use "yet" for skills still developing.
- NEVER comment on the player's body, weight, height, or appearance — only
  movement and technique.
- Every finding about a joint angle MUST end its safety_note with:
  "Check this with your coach before changing your technique."
- Give 2 or 3 concrete, named drills per finding.
- Write at a 12-year-old reading level: short sentences, no jargon without a
  quick explanation.
- NEVER invent numbers. Only restate figures that appear in the JSON facts.
"""


class Finding(BaseModel):
    fact: str
    why_it_matters: str
    # Schema-enforced: guardrails as constraints, not hopes.
    drills: list[str] = Field(min_length=2, max_length=3)
    safety_note: str


class CoachReport(BaseModel):
    highlights: list[str]
    findings: list[Finding]
    encouragement: str


def _round(x: float, nd: int = 1) -> float | None:
    """Round for the summary; NaN becomes None so it can never be narrated."""
    if x is None or (isinstance(x, float) and math.isnan(x)):
        return None
    return round(float(x), nd)


def build_summary(
    episode_stats: metrics.EpisodeStats | None,
    aggregates: dict | None,
    biomech_rows: pd.DataFrame | None,
) -> dict:
    """Compress whatever telemetry exists into the LLM-facing summary.

    Handles footwork-only, biomech-only, or both. `facts` carries the
    pre-worded plain-English statements the narrative may restate — the LLM
    is told to never invent numbers beyond these.
    """
    summary: dict = {"facts": []}
    facts: list[str] = summary["facts"]

    if episode_stats is not None and episode_stats.count > 0:
        summary["footwork"] = {
            "episode_count": episode_stats.count,
            "mean_recovery_s": _round(episode_stats.mean_latency_s),
            "median_recovery_s": _round(episode_stats.median_latency_s),
            "max_recovery_s": _round(episode_stats.max_latency_s),
            "trend_s_per_episode": _round(
                episode_stats.trend_slope_s_per_episode, 2
            ),
        }
        facts.append(
            f"Across {episode_stats.count} rallies the player took about "
            f"{_round(episode_stats.mean_latency_s)} s to recover to base "
            f"after each shot."
        )
        trend = _round(episode_stats.trend_slope_s_per_episode, 2)
        if trend is not None and trend > 0.02:
            total_drift = _round(trend * (episode_stats.count - 1))
            facts.append(
                f"Recovery got about {total_drift} s slower from the first "
                f"rally to the last — a sign of tiring legs."
            )
        elif trend is not None and trend < -0.02:
            facts.append(
                "Recovery got quicker as the session went on — a strong sign."
            )

    if aggregates is not None:
        summary["session"] = {
            "total_distance_m": _round(aggregates["total_distance_m"]),
            "duration_s": _round(aggregates["duration_s"]),
            "detection_coverage": _round(aggregates["detection_coverage"], 2),
        }
        facts.append(
            f"The player covered about {_round(aggregates['total_distance_m'], 0)} m "
            f"of court in this session."
        )

    if biomech_rows is not None and len(biomech_rows) > 0:
        summary["biomech"] = [
            {
                "window": row["window"],
                "angle": row["angle"],
                "min_deg": _round(row["min_deg"]),
                "max_deg": _round(row["max_deg"]),
            }
            for _, row in biomech_rows.iterrows()
        ]
        for _, row in biomech_rows.iterrows():
            facts.append(
                f"In the '{row['window']}' clip the {row['angle'].replace('_', ' ')} "
                f"ranged from {_round(row['min_deg'])}° to {_round(row['max_deg'])}°."
            )
            if row.get("warning"):
                facts.append(
                    f"Camera note for '{row['window']}': {row['warning']} — treat "
                    f"these angles as rough."
                )

    return summary


def generate_coach_report(
    summary: dict,
    cfg: "CoachConfig",
    extra_instruction: str | None = None,
) -> CoachReport | None:
    """One schema-constrained chat call to the local Ollama server.

    Returns None when the server is down or the model isn't pulled — the
    caller always writes the deterministic metrics report regardless. Raises
    ValueError for `-cloud` tags BEFORE any client is built: data about a
    minor never transits the internet.
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
            "the coach narrative needs the ollama package — "
            'install with: pip install "badminton-track[coach]"'
        ) from exc

    client = ollama.Client(host=cfg.ollama_host)
    user_content = json.dumps(summary)
    if extra_instruction:
        user_content += "\n\n" + extra_instruction
    try:
        resp = client.chat(
            model=cfg.model_tag,
            messages=[
                {"role": "system", "content": PERSONA_PROMPT},  # stable prefix
                {"role": "user", "content": user_content},
            ],
            format=CoachReport.model_json_schema(),
            options={"temperature": 0.4, "num_ctx": 8192},
            think=False,  # qwen3: narration gains nothing from chain-of-thought
        )
        return CoachReport.model_validate_json(resp.message.content)
    except ConnectionError:
        log.warning("Ollama not running at %s; metrics-only report", cfg.ollama_host)
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


# Body-commentary screen: the persona rules forbid it, this lint enforces it.
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


def lint_report(report: CoachReport, require_safety_notes: bool) -> list[str]:
    """Deterministic post-generation checks; empty list means clean."""
    violations: list[str] = []
    texts = [
        *report.highlights,
        report.encouragement,
        *[
            " ".join([f.fact, f.why_it_matters, *f.drills, f.safety_note])
            for f in report.findings
        ],
    ]
    for text in texts:
        lowered = text.lower()
        for term in _BANNED_TERMS:
            if term in lowered:
                violations.append(
                    f'banned body-commentary term "{term}" in: "{text[:80]}"'
                )
    if require_safety_notes:
        for finding in report.findings:
            if not finding.safety_note.strip():
                violations.append(
                    f'finding is missing its safety note: "{finding.fact[:80]}"'
                )
    return violations


def _facts_appendix(summary: dict) -> list[str]:
    lines = ["", "### Session numbers", ""]
    lines += [f"- {fact}" for fact in summary.get("facts", [])]
    return lines


def render_markdown(report: CoachReport, summary: dict) -> str:
    """Deterministic Markdown in the Flutter export style (## / ** / ---)."""
    lines = ["## Coach Report", ""]
    if report.highlights:
        lines += ["### Highlights", ""]
        lines += [f"- {h}" for h in report.highlights]
        lines.append("")
    for finding in report.findings:
        lines += [
            f"**Finding:** {finding.fact}",
            f"**Why it matters:** {finding.why_it_matters}",
            "**Drills to try:**",
            *[f"- {d}" for d in finding.drills],
        ]
        if finding.safety_note.strip():
            lines.append(f"*{finding.safety_note.strip()}*")
        lines.append("")
    lines += [f"**Keep going:** {report.encouragement}"]
    lines += _facts_appendix(summary)
    lines += ["", "---", ""]
    return "\n".join(lines)


def metrics_only_markdown(summary: dict) -> str:
    """The graceful-degradation body: facts, no narrative."""
    lines = [
        "## Coach Report",
        "",
        "_The local coach model wasn't available, so here are the measured_",
        "_facts from this session — the numbers speak for themselves._",
    ]
    lines += _facts_appendix(summary)
    lines += ["", "---", ""]
    return "\n".join(lines)


def produce_report(summary: dict, cfg: "CoachConfig") -> str:
    """Narrative markdown with one lint-retry, else the metrics-only report."""
    require_safety = "biomech" in summary
    report = generate_coach_report(summary, cfg)
    if report is None:
        return metrics_only_markdown(summary)
    violations = lint_report(report, require_safety)
    if not violations:
        return render_markdown(report, summary)
    retry = generate_coach_report(
        summary,
        cfg,
        extra_instruction=(
            "Your previous draft broke these rules: "
            + "; ".join(violations)
            + ". Rewrite the report and follow every rule."
        ),
    )
    if retry is not None and not lint_report(retry, require_safety):
        return render_markdown(retry, summary)
    log.warning("coach narrative failed lint twice; falling back to metrics-only")
    return metrics_only_markdown(summary)
