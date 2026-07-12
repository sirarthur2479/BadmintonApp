# TASK-037 - Flutter match-log data layer (schema v5 + ApiService)

**Use case:** [ideas/use-cases/match-log.md](../../ideas/use-cases/match-log.md)
**Research:** [research/fastapi-auth.md](../../research/fastapi-auth.md) (context only)
**Depends on:** TASK-035, TASK-036
**Effort:** M
**Risk:** low
**Status:** in-progress

## Goal

Persist `MatchLog` on both platforms behind `DatabaseService`'s existing
split: sqflite table via a v4→v5 migration on mobile, and new `ApiService`
methods speaking `/players/{id}/match-logs` on web (TASK-026 pattern).
Like `sessions`, the local table carries no `playerId` — mobile is
single-player offline; scoping happens server-side via the route path.

## Acceptance criteria

- `database_service.dart`: version bumped to 5; `_createMatchLogsTable`
  called from `onCreate` and from `_upgrade` (`if (oldVersion < 5)`);
  columns = `MatchLog.toMap()` keys minus nothing (id TEXT PRIMARY KEY,
  date TEXT NOT NULL, opponent TEXT NOT NULL, eventContext TEXT NOT NULL
  DEFAULT '', scores TEXT NOT NULL DEFAULT '', isWin INTEGER NOT NULL,
  gameplan TEXT NOT NULL DEFAULT '', readinessScore INTEGER NOT NULL
  DEFAULT 3, performanceNotes TEXT NOT NULL DEFAULT '', keyMoments TEXT
  NOT NULL DEFAULT '', videoRef TEXT).
- Upgrading a v4 database preserves all existing rows and gains the empty
  `match_logs` table (extend `test/services/database_migration_test.dart`).
- `DatabaseService` gains `getMatchLogs()` (sorted `date DESC`),
  `insertMatchLog`, `insertMatchLogs` (batch), `updateMatchLog`,
  `deleteMatchLog`, `hasAnyMatchLogs()` — each `kIsWeb → webApi!` first,
  matching the sessions methods.
- `ApiService` gains `getMatchLogs`, `insertMatchLog`, `insertMatchLogs`
  (POST `/match-logs/batch`), `updateMatchLog` (PUT), `deleteMatchLog`,
  `hasAnyMatchLogs` (GET `/match-logs/any` — add the `/any` route to the
  backend router if TASK-036 didn't, mirroring sessions).
- `flutter analyze` clean; all tests green.

## Test plan (RED first)

`test/services/database_service_test.dart` (extend):
- `insert and read back a match log`
- `getMatchLogs returns newest first`
- `updateMatchLog replaces fields`
- `deleteMatchLog removes the row`

`test/services/database_migration_test.dart` (extend):
- `v4 to v5 keeps sessions and adds empty match_logs table`

`test/services/api_service_test.dart` (extend, mock ApiClient pattern):
- `getMatchLogs hits GET /players/{id}/match-logs and parses the list`
- `insertMatchLog POSTs toMap payload`
- `updateMatchLog PUTs to /match-logs/{id}`
- `deleteMatchLog DELETEs /match-logs/{id}`

## Implementation plan

1. RED tests as above (sqflite tests follow the existing
   `sqflite_common_ffi` setup in `database_service_test.dart`).
2. `lib/services/database_service.dart`: add `_createMatchLogsTable`,
   bump `version: 5`, add `if (oldVersion < 5)` branch in `_upgrade`,
   add the six CRUD methods in a `── Match logs ──` section.
3. `lib/services/api_service.dart`: add the matching six methods using
   `_base` + `/match-logs`.
4. If needed, add `GET /any` to `badminton_backend/app/routers/match_logs.py`
   (one test in `tests/test_match_logs.py`).
5. GREEN: `flutter test test/services/`, `pytest` if the backend changed.
