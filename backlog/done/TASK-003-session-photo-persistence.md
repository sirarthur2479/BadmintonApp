# TASK-003 - Session photos: persist to documents dir and display them

**Use case:** [ideas/use-cases/flutter-bug-batch.md](../../ideas/use-cases/flutter-bug-batch.md)
**Research:** [badminton_flutter/docs/codebase-review-2026-07-05.md](../../badminton_flutter/docs/codebase-review-2026-07-05.md)
**Depends on:** TASK-001, TASK-002
**Effort:** M
**Risk:** low
**Status:** done

## Goal

Fix B4: a session photo currently stores the image_picker temp-cache path
(purged by iOS) and is never rendered anywhere. Copy picked photos into a
stable app-documents subfolder, store a *relative* path, and show a thumbnail
on the session card with a tap-to-view.

## Acceptance criteria

- Picking a photo copies it to `<app-docs>/session_photos/<session-id>.<ext>`;
  the session row stores the relative path `session_photos/...` (absolute
  paths break across iOS app-container moves).
- Legacy rows with absolute paths still resolve (fallback: use as-is if the
  stored path is absolute and the file exists).
- Session card in history shows a thumbnail when a photo exists; tapping opens
  a full-screen viewer. No photo → card unchanged.
- Deleting a session deletes its photo file (no orphan files).
- Web keeps working: no file copy on web (`kIsWeb` guard), picker path stored
  raw as today.

## Test plan (RED first)

- `test/services/photo_store_test.dart`
  - `savePhoto copies into session_photos and returns relative path`
  - `resolvePath returns absolute file under documents dir for relative input`
  - `resolvePath passes through existing absolute legacy paths`
  - `deletePhoto removes the file and tolerates missing files`
- `test/widgets/session_card_photo_test.dart`
  - `card shows thumbnail when photoPath resolves to an existing file`
  - `card renders without photo section when photoPath is null`

## Implementation plan

1. New `lib/services/photo_store.dart` (pure Dart + path_provider, injectable
   base dir for tests):
   - `Future<String> savePhoto(String sourcePath, String sessionId)`
   - `Future<String?> resolvePath(String stored)`
   - `Future<void> deletePhoto(String stored)`
   Constructor takes `Future<Directory> Function() getBaseDir` defaulting to
   `getApplicationDocumentsDirectory` so tests pass a temp dir.
2. `lib/screens/train/log_session_screen.dart:_pickPhoto/_save`: after pick,
   keep temp path in state; on save call `savePhoto(temp, session.id)` (skip
   on `kIsWeb`) and store the returned relative path.
3. `lib/providers/session_provider.dart:deleteSession`: call
   `deletePhoto(session.photoPath)` when set (skip on web).
4. `lib/widgets/session_card.dart`: add trailing thumbnail
   (`FutureBuilder` on `resolvePath` → `Image.file`, ~56px, rounded); wrap in
   `GestureDetector` → `showDialog` with `InteractiveViewer`.
