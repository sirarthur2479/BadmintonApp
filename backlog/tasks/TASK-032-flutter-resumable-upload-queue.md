# TASK-032 - Flutter resumable upload queue: tus client + persisted queue + attach-video UI

**Use case:** [ideas/use-cases/badmintontrack-integration.md](../../ideas/use-cases/badmintontrack-integration.md)
**Research:** [research/resumable-upload.md](../../research/resumable-upload.md)
**Depends on:** TASK-028, TASK-031
**Effort:** L
**Risk:** high

**Status:** todo

## Goal

Stage 1, client half: the owner attaches a recorded video to a training
session and the app uploads it to the LAN server with genuine resumability —
a WiFi drop or app kill mid-transfer resumes from the last server-confirmed
offset (tus HEAD re-probe), never from zero. Uploads are tracked in a
sqflite-persisted queue (mobile-only table) so pending work survives
restarts. Upload lifecycle is driven by an `UploadQueueProvider` whose
start/pause hooks are deliberately exposed so TASK-033 can gate them on
connectivity; in this task uploads start when asked to. The tus client is
wrapped behind our own interface so tests run against a fake and the `tusc`
package (adopt, per research) stays swappable if it disappoints.

## Acceptance criteria

- `pubspec.yaml`: add `tusc` (tus client, Core + Creation) and
  `image_picker` video-pick support (already present? verify — add if not).
- `lib/models/upload_task.dart`: `id, sessionId, playerId, mode
  ('footwork'|'biomech'|'full'), filePath, totalBytes, sentBytes, status
  ('pending'|'uploading'|'paused'|'done'|'failed'), tusUrl?, error?`,
  map round-trip like existing models.
- sqflite migration (next db version): `upload_queue` table storing the
  above; mobile-only (no web API mirror — feature is `kIsWeb`-gated).
- `lib/services/tus_uploader.dart`: `TusUploader` abstract interface
  (`create/resume`, `pause`, progress + completion callbacks) with a
  `TuscUploader` production impl pointed at
  `<serverAddress>/api/v1/uploads`, JWT header from
  `AnalysisServerSettings`, `Upload-Metadata` carrying
  `filename/playerId/sessionId/mode`, 8 MB chunks, persistent resume store.
- `lib/providers/upload_queue_provider.dart`:
  - `enqueue(sessionId, filePath, mode)` inserts a `pending` row (playerId
    from settings) and starts it (until TASK-033 adds the WiFi gate).
  - one active upload at a time; progress events update `sentBytes`
    (throttled writes); terminal states persist `done`/`failed` + error.
  - `resumePending()` called at startup re-drives `pending`/`paused`/
    `uploading` rows through a HEAD re-probe resume.
  - `pauseAll()` / `resumeAll()` — the seam TASK-033 gates.
- Session detail/history UI (mobile only): "Analyse video" action on a
  session → video picker + mode choice → `enqueue`; a minimal row shows
  queue state + progress (full status card is TASK-034).
- `flutter test` green with a `FakeTusUploader`; no test touches the
  network.

## Test plan

RED first:

- `test/upload_task_model_test.dart`
  - `upload task map round trip`
- `test/upload_queue_provider_test.dart` (FakeTusUploader + in-memory db)
  - `enqueue persists pending row with player from settings`
  - `enqueue starts upload and tracks progress into sentBytes`
  - `completion marks done`
  - `uploader error marks failed with message`
  - `only one upload active at a time`
  - `resumePending re-drives interrupted uploads via resume`
  - `pauseAll pauses active upload and resumeAll continues it`
- `test/upload_queue_ui_test.dart` (widget)
  - `analyse video action enqueues with session id and chosen mode`
  - `queue row shows progress and failed state`

## Implementation plan

1. Model + sqflite migration (follow the existing `database_service.dart`
   migration pattern and bump the version).
2. `TusUploader` interface + `TuscUploader` impl (thin; all logic that can
   be unit-tested lives in the provider).
3. `UploadQueueProvider` with injected `TusUploader` factory, db, and
   settings; register in `main.dart` (mobile only) and call
   `resumePending()` after startup.
4. Session UI action + queue row widget, `kIsWeb`-gated.
5. `flutter test`.
