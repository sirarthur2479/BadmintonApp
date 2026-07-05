# TASK-004 - Tournament delete UI + correct streak labels

**Use case:** [ideas/use-cases/flutter-bug-batch.md](../../ideas/use-cases/flutter-bug-batch.md)
**Research:** [badminton_flutter/docs/codebase-review-2026-07-05.md](../../badminton_flutter/docs/codebase-review-2026-07-05.md)
**Depends on:** TASK-001
**Effort:** M
**Risk:** low
**Status:** in-progress

## Goal

Fix B6 (tournaments cannot be deleted from the UI — `deleteTournament` is a
dead provider method; match delete fires with no confirmation) and B5 (the
Progress screen labels the *current* streak as "Best streak"). Extract streak
math into pure, tested functions and show both streaks.

## Acceptance criteria

- Expanded tournament tile offers Delete (with confirm dialog); confirming
  removes the tournament and its matches, and the summary badges update (B6).
- Match delete asks for confirmation before deleting (B6).
- Both destructive dialogs share one `confirmDelete(BuildContext, {title, message})`
  helper (new code only; refactoring session_history's duplicated dialogs onto
  it stays in the QoL batch).
- Progress screen shows "Current streak" and "Best streak" as two correctly
  computed tiles (B5).
- Streak math lives in pure functions with an injected `today` — no
  `DateTime.now()` inside the logic.

## Test plan (RED first)

- `test/utils/streak_test.dart`
  - `currentStreak counts consecutive days ending today`
  - `currentStreak counts a run ending yesterday`
  - `currentStreak is 0 when last session is 2+ days ago`
  - `multiple sessions on one day count once`
  - `bestStreak finds the longest historical run`
  - `bestStreak equals currentStreak when the current run is the longest`
- `test/screens/tournament_screen_test.dart`
  - `delete action shows confirm dialog and deletes on confirm`
  - `match delete shows confirm dialog and keeps the match on cancel`

## Implementation plan

1. New `lib/utils/streak.dart`:
   - `int currentStreak(Iterable<DateTime> sessionDates, DateTime today)`
   - `int bestStreak(Iterable<DateTime> sessionDates)`
2. `lib/providers/session_provider.dart`: `currentStreak` getter delegates to
   the util (passing `DateTime.now()`); add `int get bestStreak`.
3. New `lib/widgets/confirm_delete.dart`:
   `Future<bool> confirmDelete(BuildContext context, {required String title, String message = 'This cannot be undone.'})`.
4. `lib/screens/profile/tournament_screen.dart`:
   - expanded tile footer row: existing "Add match" + new delete
     `TextButton.icon` → `confirmDelete` → `provider.deleteTournament(t.id)`.
   - `_MatchRow` delete `IconButton` → `confirmDelete` first.
5. `lib/screens/profile/progress_screen.dart:37`: two tiles —
   `'Current streak' → provider.currentStreak`, `'Best streak' → provider.bestStreak`.
