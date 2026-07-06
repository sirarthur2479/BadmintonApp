# TASK-022 - Backend players CRUD with account ownership

**Use case:** [ideas/use-cases/self-hosted-backend.md](../../ideas/use-cases/self-hosted-backend.md)
**Research:** [research/fastapi-auth.md](../../research/fastapi-auth.md)
**Depends on:** TASK-021
**Effort:** S
**Risk:** low

**Status:** todo

## Goal

The Account → Players hierarchy: authenticated CRUD for players under the
caller's account, plus the single ownership helper every later data route
reuses (`require_player(playerId, accountId)` → the player row or 404).
Deleting a player cascades all their sessions/tournaments/matches/custom
tags. A caller can never see or touch another account's players, even with a
guessed UUID.

## Acceptance criteria

- `GET /api/v1/players` → players for the JWT's account only.
- `POST /api/v1/players` → creates with client-supplied UUID id; response
  echoes the full player object; missing name → 422.
- `PUT /api/v1/players/{id}` → updates profile fields; other account's
  player id → 404 (not 403 — no existence leak).
- `DELETE /api/v1/players/{id}` → removes the player and (verified in test)
  their sessions, tournaments, matches, and custom tags.
- `app/deps.py::require_player(player_id, account, conn)` shared dependency;
  all four routes use it (or the account filter for list/create).
- Player payload fields mirror the Flutter `PlayerProfile` fields plus id:
  `id, name, age, club, playingStyle, preferredGrip, shortTermGoal,
  longTermGoal, photoPath`.
- `pytest` green.

## Test plan

RED first in `badminton_backend/tests/test_players.py` (two-account fixture):

- `test_list_returns_only_own_players`
- `test_create_player_with_client_uuid`
- `test_create_player_requires_name`
- `test_update_player_fields`
- `test_update_other_accounts_player_404`
- `test_delete_player_cascades_sessions_tournaments_matches_tags`
- `test_delete_other_accounts_player_404`
- `test_all_player_routes_require_auth`

## Implementation plan

1. `app/models.py`: `PlayerIn` / `PlayerOut` pydantic models.
2. `app/deps.py`: `require_player` (SELECT by id; 404 unless
   `accountId == current account`).
3. `app/routers/players.py`: the four routes; DELETE runs explicit deletes
   for sessions/tournaments(+matches via FK cascade)/custom_tags inside one
   transaction, then the player row.
4. Mount router in `create_app`; extend `tests/conftest.py` with a
   `second_account` fixture and a `make_player` helper.
5. Full `pytest` run.
