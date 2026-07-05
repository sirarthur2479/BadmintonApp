# Use case: flutter-test-foundation

**Status:** done (TASK-005 → TASK-006, completed 2026-07-05)
**Created:** 2026-07-05
**Source:** `badminton_flutter/docs/codebase-review-2026-07-05.md` §2 (pool idea #2)

## Problem

`test/widget_test.dart` is still the default counter-app placeholder — the app
has effectively zero test coverage. The B1–B8 bug batch (TASK-001→004)
already added `test/utils/streak_test.dart`, which covers `currentStreak` and
`bestStreak` thoroughly, so that part of the original review gap is closed.
What's still untested is the rest of the pure, high-risk logic: week
bucketing (used by the progress charts) and model ↔ map/JSON round-trips
(used by every DB read/write). This is exactly the kind of logic that breaks
silently — a bad `fromMap` key or an off-by-one week boundary won't crash,
it'll just quietly show wrong numbers or drop data.

This is also the stated prerequisite for the Part A refactor (pool idea #3,
session editing + Markdown export + JSON drill storage): that work touches
`TrainingSession.toMap`/`fromMap` directly, so a round-trip test belt should
exist before it lands.

## Target users

Not end-user facing. The player/parent never see this directly; it protects
them from regressions as Part A and later features land.

## Desired outcome

Deterministic, headless (`flutter test`) coverage for the remaining untested
pure logic:

| Area | What to test | Why it's risky today |
|------|--------------|----------------------|
| Model round-trips | `TrainingSession.toMap`/`fromMap`, `Tournament.toMap`/`fromMap`, `TournamentMatch.toMap`/`fromMap`, `PlayerProfile.toJson`/`fromJson` | Comma/pipe-joined list fields (`drills`, `scores`), nullable ints, and `DateTime.toIso8601String()`/`parse` round-trips are all silent-corruption risks; no test currently exercises any of them |
| Week bucketing | `SessionProvider.sessionsPerWeek()`, `SessionProvider.avgIntensityPerWeek()` | Both compute `weekStart` via `DateTime.now()` and manual `Duration` arithmetic (`now.weekday - 1 + 7*i`); an off-by-one silently mis-buckets sessions into the wrong week on the progress charts. Currently 0 coverage. |
| Placeholder test | Remove/replace `test/widget_test.dart` | Counter-app boilerplate; asserts `true == true` and gives false confidence in `flutter test` output |

Acceptance: `flutter test` passes and covers all four model round-trips plus
week-bucketing edge cases (single session, session exactly on a week
boundary, empty week, multiple weeks).

## Constraints

- Pure logic only — no widget/integration tests in this pass (that needs a
  running app per the existing placeholder's comment).
- `sessionsPerWeek`/`avgIntensityPerWeek` call `DateTime.now()` internally
  (not injected), so tests must anchor fixture dates relative to
  `DateTime.now()` rather than fixed calendar dates, to stay deterministic
  regardless of when `flutter test` runs. (Same pattern already used
  correctly in `test/utils/streak_test.dart` via a fixed `today` — but that
  file gets to fix `today` because `currentStreak`/`bestStreak` take `today`
  as a parameter; `sessionsPerWeek` does not, so this needs either
  now-relative fixtures or a small refactor to accept an injectable "now".)
- Match existing test layout: `test/models/`, `test/providers/` (provider
  test already exists for session refresh/load-guard behaviour; extend
  rather than duplicate).
- No production code behaviour changes beyond what's needed to make
  `sessionsPerWeek`/`avgIntensityPerWeek` testable (e.g. optional `now`
  parameter), if that route is taken.

## Open questions

None blocking. One judgment call for /plan: whether to test
`sessionsPerWeek`/`avgIntensityPerWeek` purely via now-relative fixtures, or
first refactor them to accept an optional `DateTime? now` parameter (small,
low-risk change, makes tests read like `streak_test.dart`'s fixed-`today`
style). Leaning toward the small refactor since it's cheap and removes an
entire class of flakiness — /plan can decide.

## Implementation sketch

Two tasks:
1. `test/models/` round-trip tests for `TrainingSession`, `Tournament`,
   `TournamentMatch`, `PlayerProfile`.
2. `test/providers/session_provider_test.dart` additions (or a new
   `test/utils/week_bucket_test.dart` if the optional-`now` refactor is
   taken) for `sessionsPerWeek`/`avgIntensityPerWeek`, then delete/replace
   the placeholder `test/widget_test.dart`.

## Relevant domains

None requiring external research — pure Dart/Flutter unit testing with
tooling already in `pubspec.yaml` dev dependencies (`flutter_test`,
`sqflite_common_ffi`, `uuid`).
