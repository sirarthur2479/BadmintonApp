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


VALID_REPORT_JSON = (
    '{"highlights": ["Great hustle."], '
    '"findings": [{"fact": "Recovery slowed.", '
    '"why_it_matters": "Base position wins rallies.", '
    '"drills": ["Shadow ladders", "T-sprints"], '
    '"safety_note": "Check this with your coach before changing technique."}], '
    '"encouragement": "Keep building!"}'
)


class FakeResponseError(Exception):
    def __init__(self, error: str, status_code: int):
        super().__init__(error)
        self.error = error
        self.status_code = status_code


def install_fake_ollama(monkeypatch, chat_behaviour):
    """Inject a fake `ollama` module whose Client.chat runs chat_behaviour."""
    import sys
    import types

    fake = types.ModuleType("ollama")
    fake.ResponseError = FakeResponseError

    class FakeClient:
        def __init__(self, host=None):
            self.host = host

        def chat(self, **kwargs):
            return chat_behaviour(**kwargs)

    fake.Client = FakeClient
    monkeypatch.setitem(sys.modules, "ollama", fake)
    return fake


def coach_cfg(model_tag: str = "qwen3:8b"):
    from badminton_track.config import CoachConfig

    return CoachConfig(model_tag=model_tag)


def test_cloud_model_tag_rejected_before_network(monkeypatch):
    calls = []
    install_fake_ollama(monkeypatch, lambda **kw: calls.append(kw))

    with pytest.raises(ValueError, match="cloud"):
        coach.generate_coach_report({"facts": []}, coach_cfg("qwen3:8b-cloud"))

    assert calls == [], "a -cloud tag must never reach the network"


def test_generate_returns_report_on_success(monkeypatch):
    def ok(**kwargs):
        assert kwargs["model"] == "qwen3:8b"
        assert kwargs["think"] is False
        assert kwargs["format"] == coach.CoachReport.model_json_schema()

        class Msg:
            content = VALID_REPORT_JSON

        class Resp:
            message = Msg()

        return Resp()

    install_fake_ollama(monkeypatch, ok)

    report = coach.generate_coach_report({"facts": ["f"]}, coach_cfg())

    assert isinstance(report, coach.CoachReport)
    assert report.findings[0].drills == ["Shadow ladders", "T-sprints"]


def test_generate_returns_none_when_server_down(monkeypatch):
    def down(**kwargs):
        raise ConnectionError("Failed to connect to Ollama.")

    install_fake_ollama(monkeypatch, down)

    assert coach.generate_coach_report({"facts": []}, coach_cfg()) is None


def test_generate_returns_none_and_hints_pull_on_404(monkeypatch, caplog):
    def missing(**kwargs):
        raise FakeResponseError("model not found", status_code=404)

    install_fake_ollama(monkeypatch, missing)

    with caplog.at_level("WARNING"):
        result = coach.generate_coach_report({"facts": []}, coach_cfg())

    assert result is None
    assert "ollama pull" in caplog.text


def test_generate_raises_extras_missing_without_ollama(monkeypatch):
    import sys

    monkeypatch.setitem(sys.modules, "ollama", None)  # simulate not installed

    with pytest.raises(coach.ExtrasMissingError, match="coach"):
        coach.generate_coach_report({"facts": []}, coach_cfg())


def good_report() -> coach.CoachReport:
    return coach.CoachReport.model_validate_json(VALID_REPORT_JSON)


def test_lint_passes_clean_report():
    assert coach.lint_report(good_report(), require_safety_notes=True) == []


def test_lint_flags_banned_terms():
    report = good_report()
    report.highlights.append("You are getting taller and your weight helps power.")

    violations = coach.lint_report(report, require_safety_notes=False)

    assert violations, "body commentary must be flagged"
    assert any("weight" in v or "taller" in v for v in violations)


def test_lint_requires_safety_note_on_findings_when_biomech_present():
    report = good_report()
    report.findings[0].safety_note = ""

    violations = coach.lint_report(report, require_safety_notes=True)

    assert any("safety" in v.lower() for v in violations)
    # Without biomech data the same report is fine.
    assert coach.lint_report(report, require_safety_notes=False) == []


def test_produce_report_retries_once_then_falls_back(monkeypatch):
    bad = good_report()
    bad.highlights.append("your weight is an advantage")
    calls = []

    def always_bad(summary, cfg, extra_instruction=None):
        calls.append(extra_instruction)
        return bad

    monkeypatch.setattr(coach, "generate_coach_report", always_bad)
    summary = coach.build_summary(episode_stats(), aggregates(), None)

    md = coach.produce_report(summary, coach_cfg())

    assert len(calls) == 2, "exactly one retry"
    assert calls[1] is not None and "weight" in calls[1], (
        "retry must name the violation"
    )
    assert "weight" not in md, "fallback report must not contain the violation"
    assert "recover" in md.lower(), "fallback still carries the metrics facts"


def test_produce_report_returns_narrative_markdown(monkeypatch):
    monkeypatch.setattr(
        coach,
        "generate_coach_report",
        lambda summary, cfg, extra_instruction=None: good_report(),
    )
    summary = coach.build_summary(episode_stats(), aggregates(), biomech_rows())

    md = coach.produce_report(summary, coach_cfg())

    assert md.startswith("## Coach Report")
    assert "Great hustle." in md
    assert "**Why it matters:**" in md
    assert "Shadow ladders" in md
    assert "Check this with your coach" in md
    assert md.rstrip().endswith("---")


def test_metrics_only_markdown_contains_episode_stats():
    summary = coach.build_summary(episode_stats(), aggregates(), None)

    md = coach.metrics_only_markdown(summary)

    assert md.startswith("## Coach Report")
    assert "0.8" in md  # mean recovery
    assert "412" in md  # distance
    assert md.rstrip().endswith("---")


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
