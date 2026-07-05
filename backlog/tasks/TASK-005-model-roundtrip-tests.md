# TASK-005 - Model round-trip tests

**Use case:** [ideas/use-cases/flutter-test-foundation.md](../../ideas/use-cases/flutter-test-foundation.md)
**Research:** -
**Depends on:** -
**Effort:** S
**Risk:** low
**Status:** in-progress

## Goal

Add unit tests proving every model's `toMap`/`fromMap` (or `toJson`/`fromJson`)
pair round-trips without data loss, covering the specific silent-corruption
risks in each encoding: comma/pipe-joined list fields, nullable ints, boolean
stored as `0`/`1`, and `DateTime` ISO-string round-trips. These are pure Dart
functions with zero widget/DB dependencies, so they run instantly and give
the highest coverage-per-effort in the test foundation.

## Acceptance criteria

- `flutter test test/models/` passes.
- Every model in `lib/models/` with a map/JSON pair has a round-trip test:
  `TrainingSession`, `Tournament`, `TournamentMatch`, `PlayerProfile`.
- Each test covers at minimum: a "full" instance (all optional fields set)
  and an "empty/minimal" instance (nulls/defaults), asserting
  `Model.fromMap(instance.toMap())` (or `fromJson`/`toJson`) equals the
  original field-by-field.
- Edge cases specific to each model's encoding are covered:
  - `TrainingSession`: empty `drills` list, single drill, multiple drills
    (comma-join round-trip), `photoPath == null`.
  - `TournamentMatch`: empty `scores` list, multiple scores (pipe-join
    round-trip), `notes == null`, both `isWin` values.
  - `Tournament`: round-trips via `toMap()` + `fromMap(map, matches: ...)`
    since matches aren't embedded in the tournament's own map.
  - `PlayerProfile`: `age == null` / `yearsPlaying == null` vs. set,
    every `playingStyle`/`preferredGrip` default vs. explicit value.

## Test plan

RED first (write against current code, they should pass immediately since
this is characterization of existing correct behavior — no production bugs
expected here, this is a regression net):

- `test/models/session_test.dart`
  - `toMap/fromMap round-trips a full session`
  - `toMap/fromMap round-trips a session with no drills and no photo`
  - `drills with multiple entries survive the comma-join round-trip`
- `test/models/tournament_test.dart`
  - `Tournament toMap/fromMap round-trips (matches passed separately)`
  - `TournamentMatch toMap/fromMap round-trips a win with multiple scores`
  - `TournamentMatch toMap/fromMap round-trips a loss with no notes and no scores`
  - `Tournament.wins and Tournament.losses count matches correctly`
- `test/models/player_profile_test.dart`
  - `toJson/fromJson round-trips a fully-filled profile`
  - `toJson/fromJson round-trips the default (empty) profile`
  - `fromJson falls back to defaults for missing keys`

## Implementation plan

1. Create `test/models/session_test.dart`:
   - Build a `TrainingSession` with every field set (non-empty `drills`,
     `photoPath` set), assert `TrainingSession.fromMap(s.toMap())` matches
     field-by-field (compare `date` via `.isAtSameMomentAs` or
     `toIso8601String()` equality, everything else via `==`/`toString`).
   - Repeat with `drills: []` and `photoPath: null`.
2. Create `test/models/tournament_test.dart`:
   - Build a `TournamentMatch` with 2 scores and `notes` set; round-trip via
     `toMap`/`fromMap`.
   - Build one with `scores: []`, `notes: null`, `isWin: false`.
   - Build a `Tournament` (no embedded matches in the map contract), assert
     `Tournament.fromMap(t.toMap(), matches: someMatches).matches` equals
     `someMatches`.
   - Assert `wins`/`losses` getters against a small fixed list of matches.
3. Create `test/models/player_profile_test.dart`:
   - Full profile: all fields non-default, round-trip via `toJson`/`fromJson`.
   - Default `const PlayerProfile()`: round-trip.
   - `fromJson({})`: assert every field equals its constructor default.
4. Run `flutter test test/models/` and confirm all green with no production
   code changes (this task is test-only).
