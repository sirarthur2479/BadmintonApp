# TASK-023 - Backend data routes: sessions, tournaments, matches, custom tags

**Use case:** [ideas/use-cases/self-hosted-backend.md](../../ideas/use-cases/self-hosted-backend.md)
**Research:** [research/fastapi-auth.md](../../research/fastapi-auth.md)
**Depends on:** TASK-022
**Effort:** M
**Risk:** medium

**Status:** done

## Goal

The playerId-scoped data API the Flutter web client will call, with payloads
that round-trip byte-for-byte through the **current** Flutter
`toMap()/fromMap()`: sessions carry `drills` as a JSON-array string plus the
Part-A goal/reflection fields and nullable `intensity`; match `scores` stay
pipe-delimited with `isWin` as 0/1; all ids are client UUIDs; dates are ISO
strings. Every route goes through `require_player`, so the cross-account
test matrix from the plan doc ("cannot access another account's data even
with a guessed playerId") is enforced once and proven by tests.

## Acceptance criteria

- Sessions under `/api/v1/players/{playerId}/sessions`:
  `GET` (date-desc list), `POST` (upsert one, echoing Flutter's map keys
  verbatim incl. `sessionGoal`, `goalAchievementScore`, `playerRemarks`,
  `coachRemarks`, `reflectionAnswersJson`, nullable `intensity`),
  `POST .../sessions/batch` (insert-or-ignore many — the seed/migration
  path), `PUT .../sessions/{id}` (edit support from TASK-010),
  `DELETE .../sessions/{id}`, `GET .../sessions/any` → `{"any": bool}`.
- Tournaments under `/api/v1/players/{playerId}/tournaments`: `GET` (each
  with nested `matches` list), `POST`, `DELETE /{id}` (matches cascade);
  matches: `POST .../tournaments/{id}/matches`,
  `DELETE .../tournaments/{id}/matches/{mid}`; a match can only be added to
  a tournament owned by the same player.
- Custom tags under `/api/v1/players/{playerId}/tags`: `GET` (sorted),
  `POST {name}` (idempotent), `DELETE /{name}`.
- A session payload produced by Flutter's `TrainingSession.toMap()` (fixture
  copied verbatim from `session_test.dart` expectations, drills like
  `"[\"Multi-feed, front court\",\"Smash\"]"`) survives POST → GET
  unchanged, key for key.
- Cross-account matrix: every route above returns 404 for a playerId owned
  by another account; 401 without a token.
- `pytest` green.

## Test plan

RED first in `badminton_backend/tests/test_sessions.py`,
`test_tournaments.py`, `test_tags.py`:

- `test_session_flutter_map_round_trips_verbatim` (JSON-array drills with an
  embedded comma, null intensity, reflection JSON)
- `test_sessions_listed_date_desc`
- `test_session_update_and_delete`
- `test_sessions_batch_insert_ignores_duplicates`
- `test_sessions_any_flag`
- `test_tournament_with_nested_matches_round_trip` (pipe scores, isWin 0/1)
- `test_delete_tournament_cascades_matches`
- `test_match_only_attaches_to_own_players_tournament`
- `test_tags_idempotent_insert_sorted_list_delete`
- `test_cross_account_404_matrix` (parametrized over every route)
- `test_all_data_routes_require_auth`

## Implementation plan

1. `app/models.py`: `SessionIn/Out`, `TournamentIn/Out` (+nested
   `MatchOut`), `MatchIn`, `TagIn` — field names exactly the Flutter map
   keys (camelCase), `intensity: int | None`, `notes: str | None` for
   matches.
2. `app/routers/sessions.py`: routes on
   `APIRouter(prefix="/players/{player_id}/sessions",
   dependencies=[Depends(require_player)])`; upsert with
   `INSERT OR REPLACE`; batch with `INSERT OR IGNORE` + executemany.
3. `app/routers/tournaments.py`: list assembles nested matches per
   tournament (same shape `DatabaseService.getTournaments` builds locally).
4. `app/routers/tags.py`: three small routes over `custom_tags`.
5. Mount routers; parametrized cross-account fixture in `conftest.py`.
6. Full `pytest` run.
