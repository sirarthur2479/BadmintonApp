# TASK-038 - MatchLogProvider + app wiring

**Use case:** [ideas/use-cases/match-log.md](../../ideas/use-cases/match-log.md)
**Research:** [research/fastapi-auth.md](../../research/fastapi-auth.md) (context only)
**Depends on:** TASK-037
**Effort:** S
**Risk:** low
**Status:** done

## Goal

A `MatchLogProvider` following the `SessionProvider` pattern (load-once +
unconditional `refresh()`, optimistic in-memory list updates), registered in
`main.dart`'s `MultiProvider` and loaded from `MainShell.initState` alongside
sessions/tournaments/profile.

## Acceptance criteria

- `lib/providers/match_log_provider.dart`: `matchLogs` getter (newest
  first), `loadMatchLogs()` (no-op when already loaded), `refresh()`,
  `addMatchLog`, `updateMatchLog`, `deleteMatchLog` — all delegating to
  `DatabaseService` and calling `notifyListeners()`.
- Computed helpers used by the list UI: `int get wins`, `int get losses`
  (from `isWin`), `MatchLog? get latestLog`.
- Registered via `ChangeNotifierProvider` in `main.dart`;
  `MainShell.initState` calls `loadMatchLogs()`.
- Because provider methods go through `DatabaseService`, web delegation
  (TASK-037) works with no provider-side branching — same as sessions.
- `flutter analyze` clean; all tests green.

## Test plan (`test/providers/match_log_provider_test.dart`, RED first)

Follow `session_provider_test.dart` (sqflite_common_ffi + resetForTests):
- `loadMatchLogs populates from the database once`
- `refresh reloads unconditionally`
- `addMatchLog persists and prepends to the list`
- `updateMatchLog replaces the item and keeps date-desc order`
- `deleteMatchLog removes from db and memory`
- `wins and losses count isWin flags`

## Implementation plan

1. RED tests as above.
2. Create `lib/providers/match_log_provider.dart` cloned structurally from
   `SessionProvider` (minus photo/custom-tag logic).
3. `lib/main.dart`: add `ChangeNotifierProvider(create: (_) =>
   MatchLogProvider())`.
4. `lib/app.dart` `_MainShellState.initState`: add
   `context.read<MatchLogProvider>().loadMatchLogs();`.
5. GREEN: `flutter test test/providers/match_log_provider_test.dart`, full suite.
