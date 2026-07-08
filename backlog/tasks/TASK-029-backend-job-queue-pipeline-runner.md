# TASK-029 - Backend job queue: jobs table, asyncio worker, lazy badminton_track runner

**Use case:** [ideas/use-cases/badmintontrack-integration.md](../../ideas/use-cases/badmintontrack-integration.md)
**Research:** [research/background-jobs.md](../../research/background-jobs.md)
**Depends on:** TASK-028
**Effort:** M
**Risk:** medium

**Status:** todo

## Goal

Stage 3: when an upload completes (TASK-028's `on_upload_complete` seam), the
server enqueues a persisted analysis job and a single in-process asyncio
worker runs the existing `badminton_track` pipeline against it — no Redis, no
Celery, no new compose service (per research: roll-your-own `jobs` SQLite
table + worker task, kicked eagerly and recovered on startup). The pipeline
import is lazy so the backend never needs ultralytics/mediapipe/ollama
installed to boot; a missing-extras failure lands in the job row as an
actionable `failed` message, not a crash. The app polls job state via
account-scoped GET routes.

## Acceptance criteria

- `jobs` table in `app/database.py`'s `_SCHEMA` per the research doc:
  `id, playerId FK (players, CASCADE), sessionId TEXT NOT NULL, videoPath,
  mode ('footwork'|'biomech'|'full'), status
  ('queued'|'analyzing'|'done'|'failed', default 'queued'), reportPath,
  courtMapPath, errorMessage, createdAt, startedAt, finishedAt`.
  **Deviation from research:** `sessionId` is plain TEXT with **no FK** —
  mobile is offline-first, its sqflite session ids never exist in the
  server's `sessions` table; the id is an opaque correlation key the phone
  uses to attach the report back to its local session.
- `app/jobs.py`:
  - `PipelineResult(NamedTuple)` with `report_path`, `court_map_path`
    (court map optional/empty for `biomech` mode).
  - `PipelineRunner` Protocol: `(video_path: str, mode: str, out_dir: str)
    -> PipelineResult`.
  - `real_pipeline_runner` — the **only** place that imports
    `badminton_track` (lazy, inside the function body); dispatches on mode
    (`footwork.run_footwork` / `biomech.run_biomech`, then
    `coach.produce_report`); lets `ExtrasMissingError` propagate.
  - `JobWorker` holding the runner + settings: `enqueue(...) -> job row`
    (insert `queued`) and `kick(job_id)` (schedules processing on the
    running loop); processing marks `analyzing` + `startedAt`, calls the
    runner via `asyncio.to_thread` (pipeline is sync CPU-bound), then marks
    `done` (+ `reportPath`/`courtMapPath`/`finishedAt`) or `failed`
    (+ `errorMessage`/`finishedAt`). `ExtrasMissingError`'s message is
    stored verbatim. One job runs at a time (`asyncio.Lock`).
- `on_upload_complete` in `app/routers/uploads.py` now enqueues + kicks a
  job using the upload row's `playerId/sessionId/mode/storage_path`.
- Startup recovery wired in `create_app()` right after `init_db`:
  `analyzing` → `failed` ("interrupted by server restart"), `queued` →
  re-kicked once the loop is running (FastAPI startup event).
- `app/routers/jobs.py` at `/api/v1/jobs`, auth required, ownership scoped
  through the job's player's account (foreign account → 404, never 403):
  - `GET /jobs/{id}` → full job row.
  - `GET /jobs?sessionId=...` → list for that correlation id (newest first).
- Worker is injectable: `create_app(settings, runner=...)` (or
  `app.state.job_worker`) so every test uses a fake runner; no test imports
  the ML extras.
- `pytest` green.

## Test plan

RED first in `badminton_backend/tests/test_jobs.py`:

- `test_upload_complete_enqueues_queued_job`
- `test_worker_marks_analyzing_then_done_with_report_paths`
- `test_worker_failure_marks_failed_with_error_message`
- `test_extras_missing_message_stored_verbatim`
- `test_jobs_run_one_at_a_time`
- `test_startup_recovery_fails_orphaned_analyzing_jobs`
- `test_startup_recovery_rekicks_queued_jobs`
- `test_get_job_by_id_and_foreign_account_404`
- `test_list_jobs_by_session_id_newest_first`
- `test_jobs_routes_require_auth`
- `test_real_runner_reports_missing_extras_as_failed_job` (monkeypatch the
  import to raise `ExtrasMissingError`; no ML deps installed)

## Implementation plan

1. `app/database.py`: add `jobs` to `_SCHEMA`.
2. `app/jobs.py`: `PipelineResult`, `PipelineRunner`, `real_pipeline_runner`
   (lazy import + mode dispatch, writes outputs next to the video under
   `settings.upload_dir/<job_id>/`), `JobWorker` (enqueue/kick/_process with
   `asyncio.Lock` and `asyncio.to_thread`), and
   `resume_or_fail_orphaned_jobs(settings, worker)` per the research
   snippet.
3. `app/routers/uploads.py`: replace the no-op `on_upload_complete` body
   with `worker.enqueue(...)` + `worker.kick(...)` pulled from
   `request.app.state.job_worker`.
4. `app/routers/jobs.py`: the two GET routes with account scoping (join
   `jobs.playerId` → `players.accountId`).
5. `app/main.py`: construct `JobWorker` in `create_app` (runner param
   defaulting to `real_pipeline_runner`), stash on `app.state`, run
   recovery in the startup hook.
6. `tests/conftest.py`: `fake_runner` fixture (canned `PipelineResult` /
   raising variants); full `pytest`.
