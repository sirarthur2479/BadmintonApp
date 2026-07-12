# TASK-044 - Flutter point-record data layer (sqflite v6 + ApiService)

**Use case:** [ideas/use-cases/match-point-analysis.md](../../ideas/use-cases/match-point-analysis.md)
**Research:** [research/fastapi-auth.md](../../research/fastapi-auth.md) (web data-path conventions)
**Depends on:** TASK-042, TASK-043
**Effort:** M
**Risk:** low
**Status:** todo

## Goal

Persist `PointRecord`s on both surfaces exactly like match logs (TASK-037
pattern): a `point_records` sqflite table (schema v5 → v6) with CRUD on
`DatabaseService`, every method delegating to new `ApiService` methods on
web. Mobile stays offline-first; deleting a match log removes its points on
both surfaces.

## Acceptance criteria

- `database_service.dart` bumps `version:` to 6; `onCreate` and a v5→v6
  `onUpgrade` branch both create `point_records` with columns matching
  `PointRecord.toMap()` keys (`shots TEXT NOT NULL DEFAULT '[]'`,
  `matchLogId TEXT NOT NULL REFERENCES match_logs(id) ON DELETE CASCADE`).
- New `DatabaseService` methods, each with a `kIsWeb → webApi` branch:
  `getPointRecords(String matchLogId)` (ordered by game, indexInGame),
  `getAllPointRecords()`, `insertPointRecord(PointRecord)` (upsert),
  `insertPointRecords(List<PointRecord>)` (batch upsert),
  `deletePointRecord(String id)`,
  `clearPointRecords(String matchLogId)`.
- `ApiService` gains the mirror methods against
  `/players/{id}/match-logs/{logId}/points` and `/players/{id}/points`,
  serialising with the models' own `toMap`/`fromMap` (drills/shots
  JSON-string convention preserved on the wire).
- Deleting a match log on mobile cascades its point records (FK pragma is
  already on from B8); on web the backend cascade covers it.
- A real v5 database file upgrades to v6 with existing match logs intact.
- Throwing-stub guard test still proves mobile never touches `ApiService`.
- `flutter test` green, analyzer clean.

## Test plan (`test/services/point_record_db_test.dart` + additions to the API-service tests, RED first)

- `point records insert and read back ordered by game then index`
- `insertPointRecord with same id replaces the row`
- `batch insert upserts all rows`
- `clearPointRecords removes only that logs points`
- `getAllPointRecords spans match logs`
- `deleting a match log cascades its point records`
- `v5 database upgrades to v6 preserving match logs` (real-file upgrade,
  TASK-008 pattern)
- `web delegates point-record calls to ApiService` (fake ApiService
  recording calls)

## Implementation plan

1. RED tests using the existing sqflite_common_ffi harness
   (`test/services/` conventions) and the recording-fake `ApiService`
   pattern from TASK-026 tests.
2. Schema bump + `onUpgrade` v5→v6 `CREATE TABLE` (additive, no rebuild).
3. `DatabaseService` CRUD + web delegation.
4. `ApiService` methods (`_get`/`_post` helpers as for match logs).
5. GREEN per slice, then full suite.
