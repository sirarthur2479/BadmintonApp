# TASK-051 - Tactics-brief engine (badminton_track) + backend endpoint

**Use case:** [ideas/use-cases/match-point-analysis.md](../../ideas/use-cases/match-point-analysis.md)
**Research:** [research/local-llm.md](../../research/local-llm.md)
**Depends on:** TASK-050 (facts wire contract)
**Effort:** M
**Risk:** medium
**Status:** todo

## Goal

The LLM half of the brief, reusing badminton_track's guarded-Ollama
machinery (TASK-020 patterns): a `tactics` module that turns pre-worded
opponent facts into an age-appropriate tactical gameplan
(schema-constrained: 2–4 tactical recommendations + 2–3 drill suggestions +
safety-aware tone), and a thin authenticated backend endpoint the app calls
over LAN/web. Facts arrive verbatim from the client (TASK-050); the model
may narrate but never invent numbers.

## Acceptance criteria

- `badminton_track/src/badminton_track/tactics.py`:
  - `TacticsBrief` pydantic model: `summary: str`,
    `recommendations: list[str]` (2–4 enforced), `drills: list[str]`
    (2–3 enforced).
  - `generate_tactics_brief(opponent: str, facts: list[str], cfg) ->
    TacticsBrief` — same guardrails as `coach.py`: `-cloud` model tags
    refused before any network call; `ConnectionError`/404 raise the
    typed degrade error; schema-constrained chat with one named-violation
    retry; prompt embeds facts verbatim and forbids new statistics; junior
    (12-year-old) framing.
  - `render_tactics_markdown(brief, opponent, facts) -> str` — Markdown with
    a facts appendix (`_facts_appendix` pattern).
- Body-commentary lint reused: briefs must coach tactics, not body/weight.
- `badminton_backend`: `POST /api/v1/coach/opponent-brief`
  (`app/routers/coach.py`, auth = `current_account` dependency), body
  `{opponent: str, facts: list[str]}` → lazy-imports badminton_track
  (jobs `real_pipeline_runner` pattern); returns `{"markdown": ...}`;
  Ollama unreachable / extras missing → 503 with the actionable message
  (pip-install hint / "start Ollama"), never a stack trace.
- All LLM calls faked in tests (chat seam monkeypatched, TASK-020 pattern);
  no network in either suite. `pytest` green in both projects.

## Test plan (badminton_track `tests/test_tactics.py`, backend `tests/test_coach_brief.py`, RED first)

- `test_brief_schema_enforces_recommendation_and_drill_counts`
- `test_cloud_model_tag_refused_before_network`
- `test_connection_error_raises_typed_degrade`
- `test_prompt_embeds_facts_verbatim_and_bans_new_numbers`
- `test_lint_rejects_body_commentary_with_one_retry`
- `test_render_markdown_includes_facts_appendix`
- `test_endpoint_returns_markdown_from_engine` (fake engine injected)
- `test_endpoint_503_when_track_extras_missing`
- `test_endpoint_503_when_ollama_down_message_is_actionable`
- `test_endpoint_requires_auth`

## Implementation plan

1. RED: badminton_track tests first (fake chat seam fixture exists from
   coach tests), then backend endpoint tests with the engine seam faked at
   the router boundary.
2. Write `tactics.py` (share prompt/lint helpers with `coach.py` by
   extraction, not duplication — move shared guards to a `_llm_guards.py`
   if needed).
3. Write `app/routers/coach.py` + registration; reuse the lazy-import
   seam naming from `jobs.py`.
4. GREEN both suites; full pytest in both projects.
