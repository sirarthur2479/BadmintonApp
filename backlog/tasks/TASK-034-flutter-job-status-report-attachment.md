# TASK-034 - Flutter job status + report attachment: polling, status card, session report view

**Use case:** [ideas/use-cases/badmintontrack-integration.md](../../ideas/use-cases/badmintontrack-integration.md)
**Research:** [research/background-jobs.md](../../research/background-jobs.md)
**Depends on:** TASK-029, TASK-032
**Effort:** M
**Risk:** medium

**Status:** todo

## Goal

Stage 4, closing the loop: after an upload completes, the app polls
`GET /jobs?sessionId=<local session id>` on the LAN server (fire-and-forget
status card, no blocking spinner — analysis takes minutes) and, when the job
is `done`, downloads the Markdown coach report and court-map image, stores
them locally against the training session, and surfaces them in the session
detail view and Markdown export. A `failed` job shows its actionable
`errorMessage` (e.g. the missing-extras install hint) on the card. After
this task the success criterion of the whole use-case is met end-to-end.

## Acceptance criteria

- Backend addition (small, same repo): `GET /api/v1/jobs/{id}/report` and
  `/jobs/{id}/court-map` serving the job's artifacts (auth + ownership as
  TASK-029, 404 until `done`); pytest coverage alongside the existing jobs
  tests.
- `lib/models/analysis_job.dart`: `id, sessionId, mode, status, error?`,
  JSON round-trip.
- Session model + sqflite migration (next version): nullable
  `analysisReportPath`, `analysisCourtMapPath` columns; map round-trip
  updated; mobile-only columns (web export path unaffected until synced).
- `lib/providers/analysis_status_provider.dart`:
  - watches sessions with a `done` upload but no attached report; polls the
    jobs endpoint with an injectable ticker (default ~30 s while the app is
    foregrounded; no background isolate in MVP).
  - on `done`: downloads report + court map to app documents (reusing the
    `photo_store.dart` pattern), writes paths onto the session row, stops
    polling that session.
  - on `failed`: records the error for the card, stops polling.
- Status card widget on the session detail: states
  uploading (from TASK-032/033) → queued/analyzing → done (opens report) /
  failed (shows error, retry re-enqueues upload).
- Report view: renders the Markdown coach report + court-map image for a
  session; the existing Markdown export includes the coach report section
  when present.
- `flutter test` green (MockClient + fake ticker; no timers left running).

## Test plan

RED first:

- `badminton_backend/tests/test_jobs.py` additions
  - `test_report_and_court_map_download_when_done`
  - `test_artifact_routes_404_until_done_and_for_foreign_account`
- `test/analysis_job_model_test.dart`
  - `analysis job json round trip`
- `test/analysis_status_provider_test.dart`
  - `polls until done then attaches report and court map paths`
  - `failed job records error and stops polling`
  - `does not poll sessions without completed uploads`
  - `tick interval injectable and cancelled on dispose`
- `test/session_report_ui_test.dart` (widget)
  - `status card walks queued analyzing done`
  - `failed card shows error message`
  - `done card opens report view with markdown and court map`
  - `markdown export includes coach report section`

## Implementation plan

1. Backend artifact routes (`FileResponse`) + tests.
2. `AnalysisJob` model; session model columns + migration.
3. `AnalysisStatusProvider` with injected `ApiClient`-style http, db,
   settings, and ticker stream; wire into `main.dart` (mobile only).
4. Status card + report screen (`flutter_markdown` already a dep? verify;
   else render as selectable text for MVP — no new heavy deps).
5. Export service: append coach report section; `flutter test`.
