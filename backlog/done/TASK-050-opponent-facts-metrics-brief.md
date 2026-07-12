# TASK-050 - Opponent facts builder + metrics-only brief (Dart)

**Use case:** [ideas/use-cases/match-point-analysis.md](../../ideas/use-cases/match-point-analysis.md)
**Research:** [research/local-llm.md](../../research/local-llm.md) (facts-first pattern)
**Depends on:** TASK-048
**Effort:** S
**Risk:** low
**Status:** done

## Goal

The deterministic half of the tactical brief, mirroring badminton_track's
`build_summary` rule: pre-word the TASK-048 aggregates into plain-English
fact strings (the LLM can never invent or re-derive a number), and render a
metrics-only Markdown brief that stands alone — it is both the offline
fallback and the facts appendix of the LLM brief. Also the wire contract for
TASK-051: the endpoint receives these fact strings verbatim.

## Acceptance criteria

- `lib/utils/opponent_facts.dart`:
  - `List<String> opponentFacts(String displayName, OpponentStats stats)` —
    ordered, human-readable facts ("Head-to-head: won 3 of 5 matches",
    "On our serve we win 58% of points (14/24)", "Their winners come mostly
    from smash (6)"); rates rendered as whole percents with counts; any
    stat whose rate is null is SKIPPED, never rendered as NaN/null/0%.
  - `String metricsOnlyBrief(String displayName, OpponentStats stats)` —
    Markdown: `# Opponent brief — <name>`, a facts bullet list, and a
    closing note that this is metrics-only (no AI narrative), matching the
    `metrics_only_markdown` tone in badminton_track.
- Facts are stable and assertable (fixed wording templates, no timestamps).
- Export path: a share/export action for the brief reuses the existing
  `ExportService`/share_plus pattern (TASK-013/041).
- Pure Dart, no Flutter imports in the utils file.
- `flutter test` green, analyzer clean.

## Test plan (`test/utils/opponent_facts_test.dart`, RED first)

- `facts render head to head serve receive and rally bands with counts`
- `null rates are skipped never rendered`
- `percentages are whole numbers with raw counts in parentheses`
- `metrics only brief is valid markdown with name header and facts bullets`
- `metrics only brief carries the no-AI note`
- `zero tagged points yields logs-only facts`

## Implementation plan

1. RED tests on fixed fixtures (reuse TASK-048 test helpers).
2. Write `opponent_facts.dart` (templates + null-skip guard).
3. Wire an export/share action stub where TASK-052 will surface the brief
   (kept minimal here: the functions + tests are the deliverable).
4. GREEN, full suite.
