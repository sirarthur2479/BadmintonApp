# TASK-042 - PointRecord model (stage-0 contract)

**Use case:** [ideas/use-cases/match-point-analysis.md](../../ideas/use-cases/match-point-analysis.md)
**Research:** [research/shuttle-tracking.md](../../research/shuttle-tracking.md) (shot-type vocabulary)
**Depends on:** -
**Effort:** S
**Risk:** low
**Status:** todo

## Goal

Define the stage-0 contract everything else consumes: a Flutter `PointRecord`
model — one row per rally, point-level but **shot-ready** (a reserved,
JSON-encoded `shots` list that phase 2 can fill without a migration) —
following the `MatchLog`/`TrainingSession` conventions (camelCase `toMap()`
keys, ISO strings, `copyWith`, tolerant `fromMap` defaults). The `endingShot`
vocabulary stays mapped to ShuttleSet's stroke taxonomy per the research doc.

## Acceptance criteria

- `lib/models/point_record.dart` defines `PointRecord` with exactly:
  `id` (String), `matchLogId` (String), `game` (int, 1-based),
  `indexInGame` (int, 1-based), `server` (String: `player`|`opponent`),
  `winner` (String: `player`|`opponent`), `playerScore` (int, score AFTER
  the point), `opponentScore` (int), `rallyLength` (int?, shots),
  `endingType` (String: `winner`|`forcedError`|`unforcedError`),
  `endingShot` (String?, one of serve/clear/drop/smash/net/drive/lift/push/
  block/other), `endingZone` (String?, one of frontLeft/frontRight/midLeft/
  midRight/rearLeft/rearRight), `endingSide` (String?: `player`|`opponent` —
  whose half the point ended on), `videoTimestampMs` (int?),
  `shots` (List<Map<String, dynamic>>, default `[]`, reserved for phase 2).
- Shared enum-value constants live on the model (e.g.
  `PointRecord.endingShots`, `.endingZones`, `.sides`) so UI and tests never
  re-type string literals.
- `toMap()` JSON-encodes `shots` to a TEXT column-ready string (the
  sessions-drills pattern); `fromMap()` decodes it and tolerates a missing /
  empty / legacy-null value → `[]`.
- `fromMap(toMap())` round-trips every field including nullables set and
  unset; missing optional map keys fall back to documented defaults.
- `copyWith` covers every field; `flutter analyze` clean.

## Test plan (`test/models/point_record_test.dart`, RED first)

- `point record round-trips through toMap/fromMap verbatim`
- `nullable fields survive round-trip when null and when set`
- `shots list JSON-encodes to a string in toMap and decodes back`
- `fromMap tolerates missing optional keys with defaults`
- `fromMap tolerates legacy empty shots string`
- `copyWith replaces only the named fields`

## Implementation plan

1. RED tests cloned structurally from `test/models/match_log_test.dart`.
2. Write `lib/models/point_record.dart` (model + const vocabularies +
   `copyWith`/`toMap`/`fromMap`, `dart:convert` for `shots`).
3. `flutter test test/models/point_record_test.dart` → GREEN, then full suite.
