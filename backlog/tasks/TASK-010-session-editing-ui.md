# TASK-010 - Session editing: LogSessionScreen edit mode + SessionCard edit action

**Use case:** [ideas/use-cases/log-session-part-a.md](../../ideas/use-cases/log-session-part-a.md)
**Research:** - (none required; spec in `badminton_flutter/docs/log-session-improvement-plan.md` §A3)
**Depends on:** TASK-008, TASK-009
**Effort:** M
**Risk:** low

**Status:** todo

## Goal

Make existing training sessions editable end-to-end: `LogSessionScreen`
accepts an optional existing session and switches to update mode,
`SessionCard` grows an edit button next to delete, and the history screen
wires the two together. This lands on the *current* form layout — the Part D
redesign (TASK-011) builds on the edit plumbing added here.

## Acceptance criteria

- `LogSessionScreen({TrainingSession? session})`: when non-null, all form
  state (date, duration, drills, intensity, notes, photo) is pre-populated
  from the session, the app bar reads "Edit Session", and the button reads
  "Update Session".
- Saving in edit mode calls `SessionProvider.updateSession` with the same
  session `id` (never a new UUID) and pops back; history reflects the change
  immediately.
- Photo handling in edit mode: unchanged photo path is kept as-is (no
  re-copy); a newly picked photo is stored via `PhotoStore.savePhoto` and the
  old file is deleted; sessions keep working when the photo is untouched.
- Drills selected in edit mode may include custom tags / legacy drills not in
  `kDrillTypes` — pre-selection must not drop them.
- `SessionCard` gains an `onEdit` callback rendered as an edit icon beside
  the delete icon (only when non-null).
- `SessionHistoryScreen` passes `onEdit` → pushes
  `LogSessionScreen(session: session)`.
- `flutter test` fully green.

## Test plan

RED before implementation, in new
`test/screens/log_session_screen_test.dart` and extended
`test/widgets/session_card_photo_test.dart` (or new
`test/widgets/session_card_test.dart`):

- `edit mode pre-fills date, duration, drills, intensity, and notes`
- `edit mode shows Update Session button and Edit Session title`
- `updating a session keeps its id and calls updateSession, not addSession`
- `create mode still shows Log Session title and Save Session button`
- `edit mode pre-selects a drill that is not in kDrillTypes`
- `session card shows edit icon only when onEdit provided`
- `tapping edit icon invokes onEdit`

(Screen tests: pump with a `ChangeNotifierProvider<SessionProvider>` using the
existing ffi test database pattern from `test/screens/*_test.dart`.)

## Implementation plan

1. `lib/screens/train/log_session_screen.dart`:
   - Add `final TrainingSession? session;` to the widget;
     `bool get _isEditing => widget.session != null` in state.
   - `initState`: populate `_date`, `_duration`, `_selectedDrills`
     (`..addAll(widget.session!.drills)`), `_intensity`
     (`widget.session!.intensity ?? 3`), `_notesController.text`, `_photoPath`.
   - `_save`: branch — editing builds
     `widget.session!.copyWith(date:, durationMinutes:, drills:, intensity:,
     notes:, photoPath: storedPhoto)` and awaits
     `provider.updateSession(...)`; photo re-save only when
     `_photoPath != widget.session!.photoPath`, deleting the previous stored
     photo via `PhotoStore.instance.deletePhoto` after a successful save.
   - Title/button text switch on `_isEditing`.
2. `lib/widgets/session_card.dart`: add `final VoidCallback? onEdit;` and an
   `Icons.edit_outlined` GestureDetector before the delete icon.
3. `lib/screens/train/session_history_screen.dart`: pass
   `onEdit: () => Navigator.push(context, MaterialPageRoute(
   builder: (_) => LogSessionScreen(session: session)))`.
4. Full `flutter test`.
