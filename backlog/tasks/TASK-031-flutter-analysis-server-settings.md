# TASK-031 - Flutter analysis-server settings: LAN address, login, player pick, connection test

**Use case:** [ideas/use-cases/badmintontrack-integration.md](../../ideas/use-cases/badmintontrack-integration.md)
**Research:** [research/resumable-upload.md](../../research/resumable-upload.md)
**Depends on:** TASK-028
**Effort:** M
**Risk:** low

**Status:** todo

## Goal

Stage 5, pulled forward because every other client-side task needs it: a
mobile-only settings screen where the owner enters the LAN analysis-server
address once (`http://192.168.x.x:8001`, manual entry per the use-case —
mDNS is out of scope), signs in to the self-hosted account, and picks which
server-side player uploads belong to. Mobile is offline-first today and has
never authenticated (`AuthProvider` is web-only), so this introduces a
separate, self-contained `AnalysisServerProvider` that holds
address + JWT + playerId in SharedPreferences without touching the existing
web auth gate or the sqflite data path. A connection-test button proves the
address is right by hitting the tus `OPTIONS /uploads` discovery endpoint.

## Acceptance criteria

- `lib/services/analysis_server_settings.dart`: load/save of
  `serverAddress`, `token`, `playerId`, `playerName` via SharedPreferences
  (keys prefixed `analysis_`); `clear()` for sign-out.
- `lib/providers/analysis_server_provider.dart`:
  - `configure(address)` normalises the address (adds `http://` when bare,
    strips trailing `/`).
  - `login(email, password)` reuses `ApiClient` pointed at
    `<address>/api/v1`; stores the JWT; returns a user-readable error
    string on failure (same contract as `AuthProvider.login`).
  - `loadPlayers()` → GET `/players`; `selectPlayer(id, name)` persists the
    choice.
  - `testConnection()` → `OPTIONS <address>/api/v1/uploads` and succeeds
    iff the response carries `Tus-Resumable`; distinguishes
    "unreachable" from "reachable but not the analysis server" in its
    result message.
  - `isReady` — address + token + playerId all present.
- `lib/screens/settings/analysis_server_screen.dart`: address field,
  email/password sign-in, player dropdown (from `loadPlayers`), connection
  test with success/failure feedback, sign-out. Reachable from the profile
  screen. The entry point is hidden on web (`kIsWeb` gate, same
  `webOverride` test seam as `app.dart`).
- No behaviour change for existing web auth or mobile offline storage.
- `flutter test` green.

## Test plan

RED first:

- `test/analysis_server_settings_test.dart`
  - `saves and restores address token and player`
  - `clear removes all analysis keys`
- `test/analysis_server_provider_test.dart` (MockClient)
  - `configure normalises bare host and trailing slash`
  - `login stores jwt and returns null`
  - `login surfaces backend detail message on 401`
  - `loadPlayers returns account players`
  - `testConnection succeeds on tus-resumable header`
  - `testConnection fails cleanly when unreachable or wrong server`
  - `isReady only when address token and player set`
- `test/analysis_server_screen_test.dart` (widget)
  - `full flow: enter address, sign in, pick player, test connection`
  - `entry point hidden on web`

## Implementation plan

1. `lib/services/analysis_server_settings.dart` (static load/save/clear,
   mirroring `StorageService`).
2. `lib/providers/analysis_server_provider.dart` wrapping `ApiClient` with
   an injectable `http.Client` for MockClient tests; `testConnection` uses
   a raw `http.Client.send` OPTIONS request (ApiClient has no OPTIONS
   helper).
3. `lib/screens/settings/analysis_server_screen.dart`; register the
   provider in `main.dart`; profile-screen tile gated off-web.
4. `flutter test`.
