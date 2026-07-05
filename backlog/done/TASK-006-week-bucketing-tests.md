# TASK-006 - Week-bucketing tests + remove placeholder test

**Use case:** [ideas/use-cases/flutter-test-foundation.md](../../ideas/use-cases/flutter-test-foundation.md)
**Research:** -
**Depends on:** -
**Effort:** S
**Risk:** low
**Status:** done

## Goal

Cover `SessionProvider.sessionsPerWeek()` and `SessionProvider.avgIntensityPerWeek()`
with deterministic unit tests, and retire the counter-app placeholder in
`test/widget_test.dart`. Per the use-case's open-question resolution, take the
small refactor: give both methods an optional `DateTime? now` parameter
(defaulting to `DateTime.now()` so callers are unaffected) so tests can fix
"today" the same way `test/utils/streak_test.dart` already does, instead of
writing now-relative fixtures.

## Acceptance criteria

- `SessionProvider.sessionsPerWeek({int weeks, DateTime? now})` and
  `avgIntensityPerWeek({int weeks, DateTime? now})` accept the optional `now`
  and use it in place of `DateTime.now()` when provided; existing call sites
  (`progress_screen.dart`) are unaffected since the parameter defaults to
  live `DateTime.now()`.
- `flutter test test/providers/session_provider_test.dart` passes with new
  tests using a fixed `now`.
- Tests cover: a session that falls exactly on a week-start boundary (must
  count in that week, not the previous one — `weekEnd` is exclusive per the
  existing `isBefore` check), an empty week, a week with one session, a week
  with multiple sessions (average intensity math), and sessions outside the
  requested `weeks` window being excluded.
- `test/widget_test.dart` no longer contains the `true == true` placeholder;
  either deleted (since it has no replacement content per the use-case's
  "no widget tests in this pass" constraint) or the file plus its directory
  reference is removed and `flutter test` still runs clean with no missing
  file errors.

## Test plan

RED first — these fail today because `now` isn't injectable, forcing the
refactor:

- `test/providers/session_provider_test.dart` additions:
  - `sessionsPerWeek counts a session that falls on the week-start boundary`
  - `sessionsPerWeek returns 0 for a week with no sessions`
  - `sessionsPerWeek excludes sessions outside the requested window`
  - `avgIntensityPerWeek averages multiple sessions in the same week`
  - `avgIntensityPerWeek returns 0.0 for an empty week`

## Implementation plan

1. In `lib/providers/session_provider.dart`, change both method signatures:
   ```dart
   Map<DateTime, int> sessionsPerWeek({int weeks = 8, DateTime? now}) {
     final effectiveNow = now ?? DateTime.now();
     ...
   }
   Map<DateTime, double> avgIntensityPerWeek({int weeks = 8, DateTime? now}) {
     final effectiveNow = now ?? DateTime.now();
     ...
   }
   ```
   Replace the internal `now` references with `effectiveNow` in both bodies;
   no other logic changes.
2. In `test/providers/session_provider_test.dart`, add a test group using a
   fixed `today` (e.g. `DateTime(2026, 7, 10)`, a Friday) and constructing a
   `SessionProvider` seeded via `DatabaseService.insertSession` +
   `provider.refresh()` (matching the existing setup pattern in that file),
   then asserting on `provider.sessionsPerWeek(weeks: 2, now: today)` /
   `avgIntensityPerWeek(weeks: 2, now: today)`.
3. Delete `test/widget_test.dart` (no app-boot widget test exists yet to
   replace it with, per the use-case's pure-logic-only scope for this pass).
4. Run `flutter test` for the full suite and confirm green.
