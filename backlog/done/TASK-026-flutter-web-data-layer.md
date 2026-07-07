# TASK-026 - Flutter web data layer: ApiService replaces in-memory branches

**Use case:** [ideas/use-cases/self-hosted-backend.md](../../ideas/use-cases/self-hosted-backend.md)
**Research:** [research/fastapi-auth.md](../../research/fastapi-auth.md)
**Depends on:** TASK-023, TASK-025
**Effort:** M
**Risk:** medium

**Status:** done

## Goal

Make the web build persistent: a `SessionApi`/`TournamentApi` service layer
speaking the TASK-023 routes (payloads are exactly the existing
`toMap()/fromMap()` maps, so models need zero changes), and
`DatabaseService`'s `kIsWeb` branches delegating to it instead of the static
in-memory lists. Custom tags ride the same path. The active player id comes
from `PlayerProvider`; mobile code paths are byte-identical to today
(test-locked). Demo seeding stays mobile-only — web accounts start empty.

## Acceptance criteria

- `lib/services/api_service.dart`: `ApiService(ApiClient, String Function()
  activePlayerId)` with methods mirroring `DatabaseService`'s surface:
  `getSessions`, `insertSession`, `insertSessions` (batch), `updateSession`,
  `deleteSession`, `hasAnySessions`, `getTournaments`, `insertTournament`,
  `deleteTournament`, `insertMatch`, `deleteMatch`, `getCustomTags`,
  `insertCustomTag`, `deleteCustomTag` — all serializing via the models'
  existing `toMap/fromMap`.
- `DatabaseService`: every `if (kIsWeb)` branch calls a statically injected
  `ApiService` (`DatabaseService.webApi = ...` set at startup on web,
  `@visibleForTesting` swappable); the `_webSessions`/`_webTournaments`/
  `_webCustomTags` in-memory lists are deleted.
- Provider changes: none beyond construction order (providers already call
  `DatabaseService.*`) — verified by the existing provider suites passing
  untouched.
- Web startup (`main.dart`): skips `seedSampleDataIfNeeded` and constructs
  the `ApiService` chain; mobile startup unchanged.
- A round-trip test proves a `TrainingSession` with JSON-array drills and
  reflection fields serializes onto the wire and back identically (mocked
  HTTP returning what was posted).
- `flutter test` fully green (existing 124+ tests plus new ones — the
  sqflite-backed tests keep passing because non-web paths are untouched).

## Test plan

RED first in `test/services/api_service_test.dart` (MockClient):

- `getSessions parses list into TrainingSession models`
- `insertSession posts the exact toMap payload`
- `session with json-array drills and reflection round-trips the wire`
- `updateSession PUTs to the session id`
- `hasAnySessions reads the any flag`
- `tournaments round-trip with nested matches (pipe scores, isWin int)`
- `custom tags get/insert/delete hit the tags routes`
- `all calls scope urls to the active player id`
- `api errors surface as ApiException` (and, in
  `test/services/database_service_test.dart`) `non-web paths never touch
  the web api` (guard test with a throwing stub injected).

## Implementation plan

1. `api_service.dart`: URL builders
   `/players/{pid}/sessions[...]`, `/tournaments[...]`, `/tags[...]`;
   reuse `ApiClient` helpers from TASK-024.
2. `database_service.dart`: replace each web branch body with
   `return webApi!.<method>(...)`; delete the static lists; keep method
   signatures identical so providers/tests don't change.
3. `main.dart`: web-only wiring — after login/select, `DatabaseService.webApi
   = ApiService(client, () => playerProvider.activePlayer!.id)`; skip demo
   seed on web.
4. Guard test: on non-web (test env), inject a throwing `ApiService` stub
   and run a session insert through sqflite ffi to prove it is never called.
5. Full `flutter test`.
