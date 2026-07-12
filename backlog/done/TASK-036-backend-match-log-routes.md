# TASK-036 - Backend match_logs table + player-scoped routes

**Use case:** [ideas/use-cases/match-log.md](../../ideas/use-cases/match-log.md)
**Research:** [research/fastapi-auth.md](../../research/fastapi-auth.md)
**Depends on:** TASK-035 (field contract)
**Effort:** M
**Risk:** low
**Status:** done

## Goal

Give `badminton_backend` a `match_logs` table and
`/players/{player_id}/match-logs` routes mirroring `routers/sessions.py`
(TASK-023 pattern): list / upsert / batch / update / delete behind the
`require_player` ownership dependency. Columns mirror
`MatchLog.toMap()` keys exactly (camelCase pass-through, no translation).

## Acceptance criteria

- `app/database.py` `_SCHEMA` gains `match_logs`:
  `id TEXT PRIMARY KEY`, `playerId TEXT NOT NULL REFERENCES players(id) ON
  DELETE CASCADE`, `date TEXT NOT NULL`, `opponent TEXT NOT NULL`,
  `eventContext TEXT NOT NULL DEFAULT ''`, `scores TEXT NOT NULL DEFAULT ''`,
  `isWin INTEGER NOT NULL`, `gameplan TEXT NOT NULL DEFAULT ''`,
  `readinessScore INTEGER NOT NULL DEFAULT 3`,
  `performanceNotes TEXT NOT NULL DEFAULT ''`,
  `keyMoments TEXT NOT NULL DEFAULT ''`, `videoRef TEXT`.
- `app/models.py` gains `class MatchLog(BaseModel)` mirroring the Flutter
  map: `isWin: int = Field(ge=0, le=1)`, `videoRef: str | None = None`,
  string defaults as above.
- `app/routers/match_logs.py`: `GET ""` (list, `ORDER BY date DESC`),
  `POST ""` (201, INSERT OR REPLACE), `POST "/batch"` (201, INSERT OR
  IGNORE), `PUT "/{log_id}"` (404 when no row), `DELETE "/{log_id}"` (204) —
  a structural clone of `sessions.py`, router `prefix=
  "/players/{player_id}/match-logs"`, `dependencies=[Depends(require_player)]`.
- Registered in `app/main.py` under `/api/v1`.
- Unknown or foreign `player_id` → 404 before any handler runs; no auth
  code added (PyJWT + pwdlib stack untouched).
- `pytest` green.

## Test plan (`tests/test_match_logs.py`, RED first)

- `test_match_log_flutter_map_round_trips_verbatim`
- `test_list_is_ordered_by_date_desc`
- `test_post_same_id_replaces_row` (upsert)
- `test_batch_insert_ignores_duplicates`
- `test_update_missing_log_404s`
- `test_delete_removes_row`
- `test_foreign_players_logs_are_invisible` (player B can't see/hit player A's logs)
- `test_requires_auth` (401 without token)

## Implementation plan

1. Write RED tests cloned from `tests/test_sessions.py` (reuse `client`,
   `auth_headers` fixtures from `conftest.py` and `player_payload` from
   `tests/test_players.py`); a `FLUTTER_MATCH_LOG` payload dict mirrors
   TASK-035's `toMap()` output verbatim.
2. Add the table to `_SCHEMA` in `app/database.py`.
3. Add `MatchLog` to `app/models.py`.
4. Create `app/routers/match_logs.py` (`_COLS`, `_values`, `_INSERT`
   helpers as in `sessions.py`).
5. Register `match_logs_router` in `app/main.py`.
6. `pytest badminton_backend/tests/test_match_logs.py` → GREEN, then full suite.
