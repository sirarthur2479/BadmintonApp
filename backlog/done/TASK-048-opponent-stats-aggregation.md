# TASK-048 - Opponent stats aggregation (pure)

**Use case:** [ideas/use-cases/match-point-analysis.md](../../ideas/use-cases/match-point-analysis.md)
**Research:** [research/shuttle-tracking.md](../../research/shuttle-tracking.md) (vocabulary alignment)
**Depends on:** TASK-042
**Effort:** M
**Risk:** low
**Status:** done

## Goal

The deterministic profiling core: pure functions that turn match logs +
point records into per-opponent aggregates (streak-utils pattern — no I/O,
no widgets, injectable nothing). Rates must be null when their denominator
is zero; a NaN can never leak (repo convention from `build_summary`).

## Acceptance criteria

- `lib/utils/opponent_stats.dart`:
  - `String opponentKey(String name)` — trim + lowercase (exact matching per
    the use-case default; no fuzzy merge).
  - `List<OpponentSummary> opponentsFrom(List<MatchLog> logs)` — one entry
    per distinct key: display name (most recent spelling), matches, wins,
    losses, last played date.
  - `OpponentStats.compute(List<MatchLog> logs, List<PointRecord> points)`
    for one opponent key, producing:
    `matches/wins/losses`, `taggedPoints`, `pointsWonRate`,
    `serveWinRate` / `receiveWinRate` (points won when we served/received),
    rally-length bands short ≤4 / medium 5–9 / long ≥10 (each: count +
    `winRate`; null-`rallyLength` points excluded),
    `opponentWinnersByShot` (their `winner`-typed endings by shot),
    `playerUnforcedByShot` / `opponentUnforcedByShot`,
    `pressurePointsWonRate` (points where either side's pre-point score
    ≥ 18), `endingZoneCounts` (zone+side), each map sorted by count desc.
  - Every rate is `double?` — null when the denominator is 0.
- Attribution rule documented in code and tests: an `unforcedError` ending
  is attributed to the side that LOST the point; a `winner`/`forcedError`
  ending to the side that WON it.
- No dependency on providers or Flutter framework (pure Dart, importable in
  unit tests and later by the facts builder).
- `flutter test` green, analyzer clean.

## Test plan (`test/utils/opponent_stats_test.dart`, RED first)

- `opponent key trims and lowercases`
- `opponents list groups logs by key keeping latest display spelling`
- `head to head counts wins and losses`
- `points won rate across tagged points`
- `serve and receive win rates split by server`
- `rally bands bucket and exclude unknown lengths`
- `opponent winners by shot counts their finishing shots`
- `unforced errors attribute to the losing side`
- `pressure points use pre-point score of eighteen plus`
- `zone counts pair zone with side`
- `all rates are null with zero tagged points` (logs-only opponent)

## Implementation plan

1. RED: table-driven tests with hand-built fixtures (a tiny
   `point(...)` helper builds records tersely).
2. Write `opponent_stats.dart` (`OpponentSummary`, `OpponentStats` classes +
   compute functions).
3. GREEN, full suite.
