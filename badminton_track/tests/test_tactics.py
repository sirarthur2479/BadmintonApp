"""Tactics-brief engine (pool #10): guarded local-LLM gameplan from
pre-worded opponent facts. Reuses the coach test seams."""

import json

import pytest
from pydantic import ValidationError

from badminton_track import tactics

from tests.test_coach import coach_cfg, install_fake_ollama

FACTS = [
    "Head-to-head vs Ken T.: won 3 of 5 matches.",
    "On our serve we win 58% of points (14/24 tagged).",
    "Their winners come mostly from: smash (6), drop (2).",
]

VALID_BRIEF = {
    "summary": "Ken T. finishes with the smash; deny him lifts.",
    "recommendations": [
        "Serve low to the backhand.",
        "Keep lifts out of his hitting zone.",
    ],
    "drills": ["Low-serve targets", "Block-defence feeds"],
}


def ok_chat(**kwargs):
    class Resp:
        class message:
            content = json.dumps(VALID_BRIEF)

    return Resp()


def test_brief_schema_enforces_recommendation_and_drill_counts():
    with pytest.raises(ValidationError):
        tactics.TacticsBrief.model_validate({**VALID_BRIEF, "recommendations": ["one"]})
    with pytest.raises(ValidationError):
        tactics.TacticsBrief.model_validate({**VALID_BRIEF, "drills": ["only-one"]})
    tactics.TacticsBrief.model_validate(VALID_BRIEF)


def test_cloud_model_tag_refused_before_network(monkeypatch):
    calls = []
    install_fake_ollama(monkeypatch, lambda **kw: calls.append(kw))

    with pytest.raises(ValueError, match="cloud"):
        tactics.generate_tactics_brief(
            "Ken T.", FACTS, coach_cfg(model_tag="qwen3:8b-cloud")
        )
    assert calls == [], "no chat call may happen for a cloud tag"


def test_connection_error_returns_none(monkeypatch):
    def down(**kwargs):
        raise ConnectionError("no server")

    install_fake_ollama(monkeypatch, down)

    assert tactics.generate_tactics_brief("Ken T.", FACTS, coach_cfg()) is None


def test_prompt_embeds_facts_verbatim_and_bans_new_numbers(monkeypatch):
    seen = {}

    def capture(**kwargs):
        seen.update(kwargs)
        return ok_chat()

    install_fake_ollama(monkeypatch, capture)

    tactics.generate_tactics_brief("Ken T.", FACTS, coach_cfg())

    user = [m for m in seen["messages"] if m["role"] == "user"][0]["content"]
    for fact in FACTS:
        assert fact in user, "facts must reach the model verbatim"
    system = [m for m in seen["messages"] if m["role"] == "system"][0]["content"]
    assert "NEVER invent numbers" in system
    assert "12-year-old" in system


def test_lint_rejects_body_commentary_with_one_retry(monkeypatch):
    banned = dict(VALID_BRIEF, summary="Use your height advantage over him.")
    responses = [json.dumps(banned), json.dumps(VALID_BRIEF)]
    prompts = []

    def chat(**kwargs):
        prompts.append(kwargs)

        class Resp:
            class message:
                content = responses[len(prompts) - 1]

        return Resp()

    install_fake_ollama(monkeypatch, chat)

    markdown = tactics.produce_tactics_brief("Ken T.", FACTS, coach_cfg())

    assert len(prompts) == 2, "one named-violation retry"
    retry_user = [m for m in prompts[1]["messages"] if m["role"] == "user"][0][
        "content"
    ]
    assert "height" in retry_user, "the retry names the violation"
    assert markdown is not None
    assert "deny him lifts" in markdown


def test_produce_returns_none_when_llm_unreachable(monkeypatch):
    def down(**kwargs):
        raise ConnectionError("no server")

    install_fake_ollama(monkeypatch, down)

    assert tactics.produce_tactics_brief("Ken T.", FACTS, coach_cfg()) is None


def test_render_markdown_includes_facts_appendix():
    brief = tactics.TacticsBrief.model_validate(VALID_BRIEF)

    markdown = tactics.render_tactics_markdown(brief, "Ken T.", FACTS)

    assert markdown.startswith("# Tactical brief — Ken T.")
    for fact in FACTS:
        assert f"- {fact}" in markdown
    assert "Serve low to the backhand." in markdown
    assert "Low-serve targets" in markdown
