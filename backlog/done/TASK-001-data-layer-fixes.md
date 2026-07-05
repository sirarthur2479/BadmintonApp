# TASK-001 - Data layer fixes: seed-once flag, real refresh, FK pragma (+ test infra)

**Use case:** [ideas/use-cases/flutter-bug-batch.md](../../ideas/use-cases/flutter-bug-batch.md)
**Research:** [badminton_flutter/docs/codebase-review-2026-07-05.md](../../badminton_flutter/docs/codebase-review-2026-07-05.md)
**Depends on:** -
**Effort:** M
**Risk:** low
**Status:** done

## Goal

Fix the three data-layer bugs (B3 demo reseeding, B7 no-op pull-to-refresh,
B8 missing FK pragma) and, as part of making them testable, stand up the
headless DB test infrastructure (`sqflite_common_ffi`) that TASK-002/003/004
tests will reuse.

## Acceptance criteria

- Demo sessions are seeded at most once per install, gated by a
  `sample_data_seeded` SharedPreferences flag — deleting all sessions and
  restarting does NOT bring them back (B3).
- `SessionProvider.refresh()` reloads from the DB even after the initial load;
  Home's `RefreshIndicator` uses it (B7).
- `PRAGMA foreign_keys = ON` is set via `onConfigure`; deleting a tournament
  row cascades to its matches at the SQL level (B8).
- `flutter test` runs the new DB tests headless on Linux/macOS CI.

## Test plan (RED first)

- `test/services/database_service_test.dart`
  - `foreign_keys pragma is enabled on open`
  - `deleting a tournament row cascades to matches via SQL`
  - `insertSessions then getSessions round-trips`
- `test/data/seed_gate_test.dart`
  - `seeds when flag unset and db empty`
  - `does not seed when flag already set, even if db is empty`
  - `sets flag after seeding`
- `test/providers/session_provider_test.dart`
  - `refresh() picks up rows inserted behind the provider's back`
  - `loadSessions() is still a one-shot guard`

## Implementation plan

1. `pubspec.yaml`: add dev dependency `sqflite_common_ffi`.
2. `lib/services/database_service.dart`:
   - add `onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON')` to
     `openDatabase`.
   - add `@visibleForTesting static Future<void> resetForTests()` that closes
     and nulls `_db` so each test gets a fresh DB file (use `deleteDatabase`).
3. `lib/data/sample_sessions_seed.dart`: add
   `Future<bool> seedSampleDataIfNeeded(SharedPreferences prefs)` — returns
   true when it seeded; checks flag first, then `hasAnySessions()`, seeds,
   sets flag. Keep `buildSampleSessions()` as-is.
4. `lib/main.dart`: replace the inline seeding block with
   `await seedSampleDataIfNeeded(await SharedPreferences.getInstance())`.
5. `lib/providers/session_provider.dart`: add
   `Future<void> refresh()` (no `_loaded` guard, always hits
   `DatabaseService.getSessions()`); keep `loadSessions()` guarded.
6. `lib/screens/home/home_screen.dart:38`: `onRefresh: provider.refresh`.
7. Test bootstrap: in each DB test file `setUpAll`:
   `sqfliteFfiInit(); databaseFactory = databaseFactoryFfi;`
   and `SharedPreferences.setMockInitialValues({})` where prefs are used.
