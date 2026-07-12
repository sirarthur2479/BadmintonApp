# TASK-045 - PointRecordProvider + serve/score derivation utils

**Use case:** [ideas/use-cases/match-point-analysis.md](../../ideas/use-cases/match-point-analysis.md)
**Research:** [research/flutter-video.md](../../research/flutter-video.md) (tagging flow context)
**Depends on:** TASK-044
**Effort:** S
**Risk:** low
**Status:** todo

## Goal

State management for tagging plus the pure badminton-rules math that makes
tagging cheap: the server and running score are derived, never typed. Rally
scoring rules: winner of a rally serves the next rally; game to 21, win by
two, capped at 30; the winner of a game serves first in the next game — so
the only free choice is who serves first in game 1.

## Acceptance criteria

- `lib/utils/point_derivation.dart` (pure, no imports beyond the model):
  - `String serverForNext(List<PointRecord> soFar, String game1FirstServer)`
    — last point's winner; `game1FirstServer` when no points yet; previous
    game's winner right after a game boundary.
  - `({int player, int opponent}) scoreAfter(List<PointRecord> gamePoints, String winner)`
    — running score within the current game.
  - `bool isGameOver(int a, int b)` — 21+ with 2 clear, hard cap 30–29.
  - `int currentGame(List<PointRecord> soFar)` — 1-based, advances after a
    completed game.
- `lib/providers/point_record_provider.dart` follows the
  `MatchLogProvider` conventions: `loadFor(String matchLogId)` (cached,
  `refresh()` reloads), `points` (ordered), `addPoint(PointRecord)`
  (persists via `DatabaseService.insertPointRecord`, appends, notifies),
  `undoLast()` (deletes the newest point), `clearAndReplace(String
  matchLogId, List<PointRecord>)` (retag path), `allPoints()` loader for
  profiling (delegates `getAllPointRecords`).
- Registered in `main.dart`'s `MultiProvider`.
- `flutter test` green, analyzer clean.

## Test plan (`test/utils/point_derivation_test.dart`, `test/providers/point_record_provider_test.dart`, RED first)

- `first server of game 1 is the chosen side`
- `winner of a rally serves the next rally`
- `winner of a game serves first in the next game`
- `score increments for the winning side only`
- `game ends at 21 with two clear`
- `game continues at 20-20 until two clear`
- `game hard-caps at 30-29`
- `currentGame advances after a completed game`
- `provider loads points for a match log ordered`
- `addPoint persists and notifies`
- `undoLast removes the newest point`
- `clearAndReplace swaps the full set`

## Implementation plan

1. RED tests: derivation cases first (table-driven), then provider tests on
   the ffi in-memory DB harness.
2. Write `point_derivation.dart` pure functions.
3. Write `PointRecordProvider`; register in `main.dart`.
4. GREEN, full suite.
