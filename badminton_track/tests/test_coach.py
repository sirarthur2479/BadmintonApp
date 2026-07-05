import numpy as np
import pandas as pd
import pytest
from pydantic import ValidationError

from badminton_track import coach, metrics


def episode_stats() -> metrics.EpisodeStats:
    return metrics.EpisodeStats(
        count=6,
        mean_latency_s=0.82,
        median_latency_s=0.8,
        max_latency_s=1.31,
        trend_slope_s_per_episode=0.07,
    )


def aggregates() -> dict:
    return {
        "total_distance_m": 412.5,
        "duration_s": 540.0,
        "detection_coverage": 0.93,
    }


def biomech_rows() -> pd.DataFrame:
    return pd.DataFrame(
        [
            {
                "window": "smash-1",
                "angle": "smash_extension",
                "n_samples": 60,
                "min_deg": 95.0,
                "max_deg": 168.0,
                "warning": "",
            },
            {
                "window": "lunge-1",
                "angle": "knee_lunge",
                "n_samples": 45,
                "min_deg": 82.0,
                "max_deg": 175.0,
                "warning": "movement plane looks oblique",
            },
        ]
    )


def test_build_summary_footwork_only():
    summary = coach.build_summary(episode_stats(), aggregates(), None)

    assert summary["footwork"]["episode_count"] == 6
    assert summary["footwork"]["mean_recovery_s"] == pytest.approx(0.8, abs=0.05)
    assert summary["session"]["total_distance_m"] == pytest.approx(412.5)
    assert "biomech" not in summary
    # Trend must arrive pre-worded as a plain-English fact.
    assert any("recover" in f.lower() for f in summary["facts"])


def test_build_summary_combines_footwork_and_biomech():
    summary = coach.build_summary(episode_stats(), aggregates(), biomech_rows())

    assert summary["biomech"][0]["window"] == "smash-1"
    assert summary["biomech"][0]["max_deg"] == pytest.approx(168.0)
    # The oblique warning must surface as a fact the LLM merely restates.
    assert any("oblique" in f for f in summary["facts"])


def test_build_summary_biomech_only():
    summary = coach.build_summary(None, None, biomech_rows())

    assert "footwork" not in summary
    assert len(summary["biomech"]) == 2


def test_build_summary_facts_never_contain_nan():
    stats = metrics.EpisodeStats(1, 0.5, 0.5, 0.5, float("nan"))

    summary = coach.build_summary(stats, aggregates(), None)

    flat = str(summary)
    assert "nan" not in flat.lower()


def test_coach_report_schema_enforces_2_to_3_drills():
    finding = {
        "fact": "Recovery slowed 0.4 s by the session's end.",
        "why_it_matters": "Slow recovery leaves the court open.",
        "drills": ["Shadow footwork ladders"],
        "safety_note": "",
    }
    with pytest.raises(ValidationError):
        coach.Finding.model_validate(finding)

    finding["drills"] = ["Shadow footwork ladders", "T-touch sprints"]
    parsed = coach.Finding.model_validate(finding)
    assert len(parsed.drills) == 2

    finding["drills"] = ["a", "b", "c", "d"]
    with pytest.raises(ValidationError):
        coach.Finding.model_validate(finding)


def test_coach_report_round_trips_from_json():
    payload = {
        "highlights": ["Great hustle in the long rallies."],
        "findings": [
            {
                "fact": "Recovery slowed late in the session.",
                "why_it_matters": "Being back at base wins the next shot.",
                "drills": ["Shadow ladders", "T-sprints"],
                "safety_note": "Check this with your coach before changing technique.",
            }
        ],
        "encouragement": "Your effort in every rally shows — keep building!",
    }

    report = coach.CoachReport.model_validate(payload)

    assert report.findings[0].drills == ["Shadow ladders", "T-sprints"]
