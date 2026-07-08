# TASK-028 - Backend tus-subset upload router: uploads table, resumable PATCH protocol

**Use case:** [ideas/use-cases/badmintontrack-integration.md](../../ideas/use-cases/badmintontrack-integration.md)
**Research:** [research/resumable-upload.md](../../research/resumable-upload.md)
**Depends on:** -
**Effort:** M
**Risk:** medium

**Status:** in-progress

## Goal

The server half of Stage 1: implement the tus protocol's **Core + Creation**
subset by hand in `badminton_backend/` (per research — the existing
FastAPI tus libraries are 2+ years stale and byte-offset logic is too
integrity-critical to outsource), so the Flutter `tusc` client can create,
probe, and resume 1–2 GB video uploads across WiFi drops. Uploads are
JWT-authenticated and player-scoped via `Upload-Metadata`; chunks stream to
disk (never buffered whole in memory); the SQLite `uploads` row's
`offset_bytes` is the resumption source of truth, updated in the same
transaction as each flushed write. LAN-only exposure is a deployment concern
handled in TASK-030 — this task delivers the router and its full pytest
matrix.

## Acceptance criteria

- `uploads` table added to `app/database.py`'s `_SCHEMA` per the research
  doc: `id, accountId FK, playerId FK, sessionId, mode, filename,
  total_bytes, offset_bytes (default 0), storage_path, status
  ('in_progress'|'complete'|'aborted'), created_at, updated_at` (camelCase
  where the existing schema uses it; keep the file's conventions).
- `app/routers/uploads.py` mounted at `/api/v1/uploads`, all routes
  requiring auth (`current_account`):
  - `OPTIONS /uploads` → 204 with `Tus-Resumable: 1.0.0`,
    `Tus-Version: 1.0.0`, `Tus-Extension: creation`, `Tus-Max-Size`
    (4 GiB).
  - `POST /uploads` with `Upload-Length` + `Upload-Metadata` (base64
    key-value pairs carrying `filename`, `playerId`, `sessionId`, `mode`) →
    validates the player belongs to the caller (404 otherwise, reusing the
    `require_player` logic), creates a zero-length file under the uploads
    dir, inserts the row, returns `201` with `Location` and
    `Tus-Resumable` headers. Missing/invalid `Upload-Length` → 400;
    `Upload-Length` over `Tus-Max-Size` → 413.
  - `HEAD /uploads/{id}` → `Upload-Offset`, `Upload-Length`,
    `Cache-Control: no-store`; 404 for unknown/foreign-account ids; 410 for
    `complete`/`aborted`.
  - `PATCH /uploads/{id}` with `Content-Type:
    application/offset+octet-stream` and `Upload-Offset` → 409 when the
    claimed offset ≠ the stored `offset_bytes`; otherwise streams the body
    to disk at that offset (`request.stream()`), flushes, updates
    `offset_bytes` transactionally, returns 204 with the new
    `Upload-Offset`. When `offset_bytes == total_bytes`, sets
    `status='complete'` (TASK-029's enqueue hook attaches here — for now a
    no-op seam `on_upload_complete(upload_row)` is called).
  - `DELETE /uploads/{id}` → marks `aborted`, unlinks the partial file, 204.
- Per-upload `asyncio.Lock` so overlapping PATCHes for one id cannot race
  the offset (verified by test).
- Wrong `Content-Type` on PATCH → 415; missing `Tus-Resumable` header on
  POST/PATCH → 412 (protocol precondition).
- Upload directory (`settings.upload_dir`, default `data/uploads/`) is
  created on demand and covered by the existing `.gitignore` (`data/`).
- Full-file integrity: a test uploads a known byte pattern in 3 chunks with
  a simulated drop + HEAD re-probe between chunks, then asserts the
  reassembled file is byte-identical.
- `pytest` green.

## Test plan

RED first in `badminton_backend/tests/test_uploads.py`:

- `test_options_advertises_tus_core_and_creation`
- `test_create_upload_returns_location_and_zero_offset`
- `test_create_parses_metadata_and_scopes_to_own_player`
- `test_create_foreign_player_404`
- `test_create_missing_upload_length_400_and_oversize_413`
- `test_head_reports_current_offset`
- `test_head_unknown_id_404_and_complete_410`
- `test_patch_appends_chunk_and_advances_offset`
- `test_patch_wrong_offset_409`
- `test_patch_wrong_content_type_415`
- `test_missing_tus_resumable_header_412`
- `test_three_chunk_upload_with_reprobe_reassembles_byte_identical`
- `test_final_chunk_marks_complete_and_fires_completion_seam`
- `test_delete_aborts_and_unlinks_partial_file`
- `test_all_upload_routes_require_auth`

## Implementation plan

1. `app/settings.py`: add `upload_dir` (env `UPLOAD_DIR`, default
   `data/uploads`).
2. `app/database.py`: `uploads` table in `_SCHEMA`.
3. `app/routers/uploads.py`: `_parse_metadata(header) -> dict` (base64
   pairs per tus spec), module-level `_locks: dict[str, asyncio.Lock]`
   keyed by upload id, `on_upload_complete(row, request)` seam (no-op until
   TASK-029), the five endpoints. PATCH handler:
   `async for chunk in request.stream(): f.write(chunk)` after
   `f.seek(offset)`; `f.flush(); os.fsync()` before the SQLite update.
4. Mount in `create_app`; extend `tests/conftest.py` with an
   `upload_headers(...)` helper building tus headers + metadata.
5. Full `pytest` run.
