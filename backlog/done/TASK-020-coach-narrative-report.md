# TASK-020 - Coach narrative: metrics summary, Ollama guardrails, Markdown report

**Use case:** [ideas/use-cases/badmintontrack-12.md](../../ideas/use-cases/badmintontrack-12.md)
**Research:** [research/local-llm.md](../../research/local-llm.md)
**Depends on:** TASK-016, TASK-019
**Effort:** M
**Risk:** medium

**Status:** todo

## Goal

Module 4 and the Stage-3 merger: deterministically compress whatever
telemetry exists for a session (footwork episodes/trend, biomech angle
min/max, pre-worded anomaly facts — the LLM never sees per-frame data and
never does arithmetic) into a compact summary; send it to a local Ollama
model (`qwen3:8b`, `think=False`) under a layered persona prompt with
schema-constrained output (Pydantic `CoachReport` via
`format=model_json_schema()`); render the Markdown deterministically in
Python in a structure compatible with the Flutter app's session-export
format; lint the result (banned body-commentary terms, mandatory safety
notes) with one named-violation retry; and degrade gracefully to a
metrics-only report when Ollama is down or the model isn't pulled. Refuse
`-cloud` model tags outright.

## Acceptance criteria

- `src/badminton_track/coach.py` with:
  - `build_summary(episode_stats, aggregates, biomech_rows) -> dict` —
    compact JSON-safe dict; every anomaly pre-worded as a plain-English
    fact string; handles footwork-only / biomech-only / both.
  - `class CoachReport(BaseModel)`: `highlights: list[str]`,
    `findings: list[Finding]` (`fact`, `why_it_matters`,
    `drills: list[str]` (2–3 items, schema-enforced), `safety_note`),
    `encouragement: str`.
  - `PERSONA_PROMPT` module constant (stable byte-identical prefix):
    growth-mindset rules, no body commentary, the mandatory safety line for
    joint-angle findings, ~12-year-old reading level, never invent numbers.
  - `generate_coach_report(summary, cfg) -> CoachReport | None` — the ONLY
    ollama import (lazy); `client.chat(model=cfg.model_tag, messages=[system,
    user], format=CoachReport.model_json_schema(),
    options={"temperature": 0.4}, think=False)`; returns None on
    `ConnectionError` (server down) and `ollama.ResponseError` (404 → "model
    not pulled" hint logged); `ExtrasMissingError` without the coach extra;
    raises `ValueError` for any model tag ending in `-cloud` BEFORE any
    network call.
  - `lint_report(report) -> list[str]` — banned-term screen (body/appearance
    words) + biomech findings must carry a non-empty safety note; caller
    retries once with violations named, then falls back.
  - `render_markdown(report, summary) -> str` — deterministic; `##`-headed
    sections mirroring the Flutter `ExportService` style (`## Coach Report —
    <date>`, `**...:**` bold labels, `---` terminator); metrics appendix
    from the summary, not the LLM.
  - `metrics_only_markdown(summary) -> str` — the graceful-degradation body.
- `badminton-track report <session-stem>` CLI subcommand: loads whatever
  telemetry/summaries exist under `data/`+`output/` for that stem, writes
  `output/<stem>-coach-report.md`; exit 0 with metrics-only report + warning
  when the LLM is unavailable.
- `pytest` green without the `ollama` package (client fully mocked).

## Test plan

RED first in `badminton_track/tests/test_coach.py`:

- `test_build_summary_footwork_only`
- `test_build_summary_combines_footwork_and_biomech`
- `test_coach_report_schema_enforces_2_to_3_drills`
- `test_cloud_model_tag_rejected_before_network`
- `test_generate_returns_none_when_server_down` (mock raises ConnectionError)
- `test_generate_returns_none_and_hints_pull_on_404`
- `test_lint_flags_banned_terms`
- `test_lint_requires_safety_note_on_biomech_findings`
- `test_retry_once_then_fallback_on_persistent_lint_failure`
- `test_render_markdown_matches_flutter_export_conventions`
- `test_metrics_only_markdown_contains_episode_stats`
- `test_cli_report_writes_markdown_and_warns_without_llm` (in `test_cli.py`)

## Implementation plan

1. `coach.py`: `Finding` + `CoachReport` pydantic models
   (`drills: list[str] = Field(min_length=2, max_length=3)`).
2. `build_summary`: dicts of pre-formatted strings + raw numbers
   (latencies rounded to 0.1 s, angles to 1°); anomaly wording helpers.
3. `PERSONA_PROMPT` with the rule list from `research/local-llm.md` §Persona
   guardrails (stable prefix; per-run JSON goes in the user message).
4. `generate_coach_report`: lazy `import ollama` in-function; the exact
   call/except structure from the research doc; tag guard first.
5. `lint_report` + `_BANNED_TERMS` list; retry loop lives in the CLI-facing
   `produce_report(...)` helper so `generate_coach_report` stays single-shot.
6. `render_markdown` / `metrics_only_markdown` string builders.
7. CLI `report` subcommand + `CoachConfig` already holds tags/host from
   TASK-014.
8. Full `pytest` run; optional integration test skipped unless a live Ollama
   answers `client.list()`.
