# TASK-039 - TrainScreen tab container + match-log list

**Use case:** [ideas/use-cases/match-log.md](../../ideas/use-cases/match-log.md)
**Research:** -
**Depends on:** TASK-038
**Effort:** M
**Risk:** medium
**Status:** done

## Goal

Turn the Train tab into a two-sub-tab container: **Sessions** (existing
`SessionHistoryScreen` content) and **Match Logs** (new list of
`MatchLogCard`s with an empty state and a FAB). `TrainScreen` replaces
`SessionHistoryScreen` in `MainShell._tabs` without breaking web's
login → player-select → shell routing.

## Acceptance criteria

- `lib/screens/train/train_screen.dart`: `DefaultTabController` with a
  single AppBar ("Train") hosting a `TabBar` (Sessions / Match Logs) and
  per-tab bodies. The Sessions tab shows the existing session list,
  pull-to-refresh, export action, and log-session FAB exactly as today
  (refactor `SessionHistoryScreen`'s body/FAB/actions rather than nesting
  a second Scaffold+AppBar).
- Match Logs tab: `Consumer<MatchLogProvider>`; empty state (icon + "No
  match logs yet" text, style of the sessions empty state); otherwise a
  `ListView` of `MatchLogCard`s, newest first; pull-to-refresh calls
  `provider.refresh()`; FAB navigates to `LogMatchScreen` (TASK-040 —
  until it lands, the FAB can push a placeholder scaffold).
- `lib/widgets/match_log_card.dart`: shows date, opponent, event context,
  scores, a win/loss chip, and readiness stars (`StarRating`); tap →
  edit (wired in TASK-040); delete via the existing `confirm_delete.dart`
  dialog → `provider.deleteMatchLog`.
- `MainShell._tabs[1]` becomes `TrainScreen()`; bottom-nav item unchanged.
- Existing session-history and web-routing tests still pass.
- `flutter analyze` clean.

## Test plan (`test/screens/train_screen_test.dart`, RED first)

- `Train tab shows Sessions and Match Logs tabs`
- `Sessions tab still lists sessions` (seeded provider)
- `Match Logs tab shows empty state when provider has no logs`
- `Match Logs tab lists a card per log, newest first`
- `win chip shows for isWin true and loss chip for false`
- `delete flows through the confirm dialog`
- extend `test/widgets/` with `match_log_card_test.dart` if card logic
  warrants isolated tests (stars count, date formatting)

## Implementation plan

1. RED widget tests (pump with `MultiProvider` fakes, pattern from
   `home_screen_test.dart` / existing screen tests).
2. Create `lib/widgets/match_log_card.dart` (style from `session_card.dart`).
3. Create `lib/screens/train/train_screen.dart`; move
   `SessionHistoryScreen`'s body into it (keep the file exporting the
   session list widget for reuse, or inline and delete — prefer keeping
   `SessionHistoryScreen` as the Sessions tab body widget minus its own
   Scaffold).
4. Swap `SessionHistoryScreen()` → `TrainScreen()` in `lib/app.dart`.
5. GREEN: `flutter test test/screens/train_screen_test.dart`, then the
   full suite (watch `session_report_ui_test.dart` and any test pumping
   `MainShell`).
