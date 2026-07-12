# TASK-035 - MatchLog model + round-trip tests

**Use case:** [ideas/use-cases/match-log.md](../../ideas/use-cases/match-log.md)
**Research:** [research/fastapi-auth.md](../../research/fastapi-auth.md) (context only — no new research)
**Depends on:** -
**Effort:** S
**Risk:** low
**Status:** done

## Goal

Define the `MatchLog` Dart model — the field contract every other task
(local DB, backend, API, UI) builds against. A standalone per-match
reflection record, not tied to a `tournamentId`, following the exact
`copyWith`/`toMap`/`fromMap` conventions of `TrainingSession`
(`badminton_flutter/lib/models/session.dart`).

## Fields

| Field | Dart type | Map encoding | Default |
|---|---|---|---|
| `id` | `String` | as-is | required |
| `date` | `DateTime` | ISO-8601 string | required |
| `opponent` | `String` | as-is | required |
| `eventContext` | `String` | as-is (free text: "Practice", "League", "Tournament R16") | `''` |
| `scores` | `String` | as-is (free-form, e.g. "21-15, 18-21, 21-19") | `''` |
| `isWin` | `bool` | `1`/`0` int (same as `TournamentMatch`) | required |
| `gameplan` | `String` | as-is (pre-match plan) | `''` |
| `readinessScore` | `int` 1–5 | as-is (mirrors `goalAchievementScore`) | `3` |
| `performanceNotes` | `String` | as-is (post-match: what worked / broke down) | `''` |
| `keyMoments` | `String` | as-is | `''` |
| `videoRef` | `String?` | as-is, nullable (path or URL) | `null` |

## Acceptance criteria

- `MatchLog` is `const`-constructible, immutable, with `copyWith`, `toMap`,
  `fromMap` matching the table above key-for-key (camelCase keys).
- `fromMap` tolerates missing optional keys (nulls / absent → defaults),
  same as `TrainingSession.fromMap`.
- `toMap` → `fromMap` round-trips losslessly, including `isWin` bool↔int
  and `date` DateTime↔ISO string.
- `flutter analyze` clean; all tests green.

## Test plan (`test/models/match_log_test.dart`, RED first)

- `toMap/fromMap round-trips a fully-populated log`
- `toMap encodes isWin true as 1 and false as 0`
- `fromMap parses ISO date string back to the same DateTime`
- `fromMap applies defaults for missing optional fields`
- `fromMap accepts null videoRef`
- `copyWith replaces only the given fields`

## Implementation plan

1. Write the RED tests in
   `badminton_flutter/test/models/match_log_test.dart`, cloned in style from
   `test/models/session_test.dart`.
2. Create `badminton_flutter/lib/models/match_log.dart`:
   `class MatchLog` with the fields above;
   `MatchLog copyWith({...})`; `Map<String, dynamic> toMap()`;
   `factory MatchLog.fromMap(Map<String, dynamic> map)`.
3. `flutter test test/models/match_log_test.dart` → GREEN, then full suite.
