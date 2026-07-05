"""Module 4 — local-LLM coach narrative.

The LLM never sees per-frame data and never does arithmetic: all statistics
are computed here (pandas/numpy) and handed over as a compact summary whose
anomalies are already worded as plain-English facts. The model only narrates.
"""

import math
from typing import TYPE_CHECKING

import pandas as pd
from pydantic import BaseModel, Field

from . import metrics

if TYPE_CHECKING:
    from .config import CoachConfig


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
