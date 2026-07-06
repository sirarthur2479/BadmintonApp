# TASK-025 - Flutter player select: PlayerProvider, select screen, switcher

**Use case:** [ideas/use-cases/self-hosted-backend.md](../../ideas/use-cases/self-hosted-backend.md)
**Research:** [research/fastapi-auth.md](../../research/fastapi-auth.md)
**Depends on:** TASK-024
**Effort:** M
**Risk:** low

**Status:** todo

## Goal

The Account → Players hierarchy on the client (web flow): a `PlayerProvider`
that loads the account's players from `/api/v1/players`, holds the active
player (persisted so a refresh remembers it), and a `PlayerSelectScreen`
(grid of player cards + "Add Player") shown after login — auto-skipped when
the account has exactly one player. A switcher entry point returns to the
select screen without logging out. Mobile remains untouched.

## Acceptance criteria

- `lib/models/player.dart`: `Player` model matching the backend payload
  (`id, name, age, club, playingStyle, preferredGrip, shortTermGoal,
  longTermGoal, photoPath`), `toMap/fromMap` round-trip tested.
- `lib/providers/player_provider.dart`: `loadPlayers()`, `players`,
  `activePlayer`, `switchPlayer(id)` (persists `active_player_id` to prefs
  and restores it), `addPlayer(...)` (POST with client UUID),
  `clear()` on logout.
- `lib/screens/player/player_select_screen.dart`: card per player, tap →
  sets active + enters `MainShell`; "Add Player" dialog (name required);
  logout action in the app bar.
- Post-login routing in `app.dart` (web): no active player → select screen;
  exactly 1 player and none active → auto-select it; active player set →
  `MainShell`.
- Switcher: an app-bar action on the Profile tab (web only) that clears the
  active player, returning to the select screen with the session intact.
- All tests mock the `ApiClient` — no live backend.
- `flutter test` fully green.

## Test plan

RED first in `test/models/player_test.dart`,
`test/providers/player_provider_test.dart`,
`test/screens/player_select_screen_test.dart`:

- `player toMap/fromMap round-trips all fields`
- `loadPlayers populates from api`
- `switchPlayer persists and restores active id across provider instances`
- `addPlayer posts with generated uuid and appends`
- `clear wipes players and active id`
- `select screen renders one card per player`
- `tapping a card sets the active player`
- `add player dialog requires a name`
- `single-player account auto-selects on load`

## Implementation plan

1. `lib/models/player.dart` (+ default empty strings mirroring
   `PlayerProfile` semantics).
2. `player_provider.dart` with injected `ApiClient` and
   `SharedPreferences`-persisted active id.
3. `player_select_screen.dart` (GridView of Cards, `ProfileAvatar` reuse,
   add-player `AlertDialog`).
4. `app.dart` web routing: `AuthProvider` × `PlayerProvider` consumer chain;
   register provider in `main.dart`.
5. Profile-tab switcher `IconButton` behind `kIsWeb`.
6. Full `flutter test`.
