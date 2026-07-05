# TASK-008 - DB v1→v2 migration (sessions rebuild), updateSession, custom_tags

**Use case:** [ideas/use-cases/log-session-part-a.md](../../ideas/use-cases/log-session-part-a.md)
**Research:** - (none required; spec in `badminton_flutter/docs/log-session-improvement-plan.md` migration summary)
**Depends on:** TASK-007
**Effort:** M
**Risk:** medium

**Status:** todo

## Goal

Bump the sqflite schema to version 2. Because v1 declares
`intensity INTEGER NOT NULL` and Part A makes intensity nullable, the
migration must **rebuild** the sessions table (create new → copy/convert →
drop → rename), converting each row's comma-joined `drills` to a JSON array
in the same pass. Add the `custom_tags` table, an `updateSession` write path,
and custom-tag CRUD — all mirrored in the web in-memory branch.

## Acceptance criteria

- `_initDb` opens at `version: 2`.
- `onCreate` (fresh install) creates the v2 `sessions` schema directly:
  `intensity INTEGER` (nullable), plus `sessionGoal TEXT NOT NULL DEFAULT ''`,
  `goalAchievementScore INTEGER NOT NULL DEFAULT 3`,
  `playerRemarks TEXT NOT NULL DEFAULT ''`, `coachRemarks TEXT NOT NULL DEFAULT ''`,
  `reflectionAnswersJson TEXT NOT NULL DEFAULT '[]'`; and
  `CREATE TABLE custom_tags (name TEXT PRIMARY KEY)`.
- `onUpgrade` from v1: existing rows survive with `drills` converted from
  comma-joined to JSON array text, `intensity` preserved, new columns at
  defaults; `custom_tags` created. `PRAGMA foreign_keys` handling unchanged.
- `DatabaseService.updateSession(TrainingSession session)` performs SQL
  `UPDATE ... WHERE id = ?` (web: replaces the matching `_webSessions` entry).
- `DatabaseService.getCustomTags() → Future<List<String>>`,
  `insertCustomTag(String name)` (idempotent), `deleteCustomTag(String name)`;
  web branch backed by a static in-memory list.
- Inserting a session with `intensity: null` succeeds on both fresh-install
  and migrated databases.
- `flutter test` fully green.

## Test plan

RED before implementation, in `test/services/database_service_test.dart`
(extend; uses existing `dbName`/`resetForTests` hooks with `sqflite_common_ffi`):

- `migration v1→v2 preserves sessions and converts comma drills to JSON`
  (create the db file at version 1 with the old schema via a raw
  `openDatabase(version: 1)`, insert a row with `drills = 'Smash,Footwork'`
  and `intensity = 4`, close, then let `DatabaseService` reopen → assert
  `getSessions()` returns the row with `['Smash', 'Footwork']` and intensity 4)
- `migration leaves new columns at defaults for legacy rows`
- `fresh v2 install accepts a session with null intensity`
- `updateSession persists modified goal, drills, and reflection fields`
- `custom tags: insert, list, delete round-trip; duplicate insert is a no-op`

## Implementation plan

1. `lib/services/database_service.dart`:
   - `version: 2`; extract `_createSessionsV2(Database db)` and
     `_createCustomTags(Database db)` used by both `onCreate` and `onUpgrade`.
   - `onUpgrade(db, oldV, newV)`: if `oldV < 2` —
     `CREATE TABLE sessions_new (v2 schema)`; `SELECT * FROM sessions`,
     for each row re-encode `drills` via
     `jsonEncode(raw.isEmpty ? [] : raw.split(','))` and insert into
     `sessions_new`; `DROP TABLE sessions`;
     `ALTER TABLE sessions_new RENAME TO sessions`; create `custom_tags`.
     Wrap in a transaction.
2. `updateSession`: `db.update('sessions', session.toMap(), where: 'id = ?',
   whereArgs: [session.id])`; web: index-replace in `_webSessions`.
3. Custom tags: `_webCustomTags` static list for web;
   `insertCustomTag` with `ConflictAlgorithm.ignore`;
   `getCustomTags` ordered by name.
4. Run the new tests plus the full suite; verify `seed_gate_test.dart` still
   passes (seed inserts go through the new schema).
