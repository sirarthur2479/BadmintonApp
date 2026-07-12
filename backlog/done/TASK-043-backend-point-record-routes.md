# TASK-043 - Backend point_records table + nested routes

**Use case:** [ideas/use-cases/match-point-analysis.md](../../ideas/use-cases/match-point-analysis.md)
**Research:** [research/fastapi-auth.md](../../research/fastapi-auth.md) (stack rules)
**Depends on:** TASK-042 (field contract)
**Effort:** M
**Risk:** low
**Status:** done

## Goal

Give `badminton_backend` a `point_records` table and routes nested under
match logs — `/players/{player_id}/match-logs/{log_id}/points` — mirroring
the sessions/match-logs router pattern (TASK-023/036), plus a flat
`/players/{player_id}/points` listing for opponent profiling. Columns mirror
`PointRecord.toMap()` keys verbatim; `shots` is an opaque JSON TEXT
pass-through, never re-encoded.

## Acceptance criteria

- `app/database.py` `_SCHEMA` gains `point_records`: `id TEXT PRIMARY KEY`,
  `matchLogId TEXT NOT NULL REFERENCES match_logs(id) ON DELETE CASCADE`,
  `game INTEGER NOT NULL`, `indexInGame INTEGER NOT NULL`,
  `server TEXT NOT NULL`, `winner TEXT NOT NULL`,
  `playerScore INTEGER NOT NULL`, `opponentScore INTEGER NOT NULL`,
  `rallyLength INTEGER`, `endingType TEXT NOT NULL`, `endingShot TEXT`,
  `endingZone TEXT`, `endingSide TEXT`, `videoTimestampMs INTEGER`,
  `shots TEXT NOT NULL DEFAULT '[]'`.
- `app/models.py` gains `class PointRecord(BaseModel)` mirroring the map:
  `server`/`winner` validated to `player|opponent`, `endingType` to
  `winner|forcedError|unforcedError`, `shots: str = "[]"`, nullables as in
  TASK-042.
- `app/routers/point_records.py`, router prefix
  `/players/{player_id}/match-logs/{log_id}/points`,
  `dependencies=[Depends(require_player)]`, with an own-match-log guard
  (foreign/unknown `log_id` → non-leaking 404 — the tournaments/matches
  pattern): `GET ""` (list, `ORDER BY game, indexInGame`), `POST ""`
  (201, INSERT OR REPLACE), `POST "/batch"` (201, INSERT OR REPLACE, for
  save-all-at-once tagging), `DELETE "/{point_id}"` (204), `DELETE ""`
  (204, clear-all — the retag path).
- Same file also exposes `GET /players/{player_id}/points` (flat, all of a
  player's point records, `ORDER BY matchLogId, game, indexInGame`) behind
  `require_player` — the opponent-profiling feed on web.
- Registered in `app/main.py` under `/api/v1`.
- Deleting a match log cascades its point records (FK, existing pragma).
- No auth code added; `pytest` green.

## Test plan (`tests/test_point_records.py`, RED first)

- `test_point_record_flutter_map_round_trips_verbatim`
- `test_list_ordered_by_game_then_index`
- `test_post_same_id_replaces_row`
- `test_batch_replaces_existing_ids`
- `test_clear_all_removes_only_this_logs_points`
- `test_flat_player_points_lists_across_logs`
- `test_foreign_match_log_404s_before_handler` (player B's log id + own auth)
- `test_unknown_match_log_404s`
- `test_deleting_match_log_cascades_points`
- `test_requires_auth`

## Implementation plan

1. RED tests cloned from `tests/test_match_logs.py`; a
   `FLUTTER_POINT_RECORD` payload dict mirrors TASK-042 `toMap()` output
   (with `shots` as the JSON string `"[]"`).
2. Add the table to `_SCHEMA`; add `PointRecord` to `app/models.py`
   (pydantic `Literal` or validators for the closed vocabularies).
3. Create `app/routers/point_records.py`: `_require_own_match_log(...)`
   helper (SELECT by id + playerId → 404), `_COLS`/`_values`/`_INSERT`
   helpers as in `match_logs.py`; flat listing route in the same module with
   its own `APIRouter` or an absolute-path route.
4. Register in `app/main.py`.
5. `pytest tests/test_point_records.py` → GREEN, then full suite.
