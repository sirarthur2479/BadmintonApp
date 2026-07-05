# TASK-013 - Markdown export: ExportService, single-session share, bulk export screen

**Use case:** [ideas/use-cases/log-session-part-a.md](../../ideas/use-cases/log-session-part-a.md)
**Research:** - (none required; spec in `badminton_flutter/docs/log-session-improvement-plan.md` Part E, sessions scope)
**Depends on:** TASK-007, TASK-011
**Effort:** M
**Risk:** low

**Status:** todo

## Goal

Give session history an exit path for AI analysis and coach sharing: a pure
`ExportService` that renders training sessions to the plan's documented
Markdown format, a share button on the edit screen for a single session, and
a bulk export screen (date range + preview count → combined Markdown →
system share sheet). Match-log export is explicitly out of scope until
Part B exists.

## Acceptance criteria

- `share_plus` added to `pubspec.yaml`.
- `lib/services/export_service.dart` with:
  - `static String sessionToMarkdown(TrainingSession s)` producing the plan
    format: `## Training Session — <EEE, d MMM yyyy>` header, `**Goal:**`,
    `**Duration:** N min | **Goal Achievement:** ★★★★☆` (unicode stars,
    empty stars `☆`), `**Drills:**` comma-separated, `### Reflection`
    numbered answered questions (unanswered skipped), `**Done Well (Player):**`
    and `**Coach Remarks:**` when non-empty, trailing `---`.
  - `static String bulkExport({required List<TrainingSession> sessions,
    required DateTime from, required DateTime to})` — filters to the
    inclusive date range, orders chronologically (oldest first), joins
    per-session Markdown under a titled header with the range and count.
- Legacy sessions (empty goal, null intensity) export without crashing;
  empty optional lines are omitted rather than rendered blank.
- `LogSessionScreen` in edit mode shows a share `IconButton` in the app bar
  that shares `sessionToMarkdown(widget.session!)` via `Share.share`.
- `lib/screens/export_screen.dart` (new): from/to date pickers (default:
  last 30 days), live preview count ("N sessions in range"), "Export as
  Markdown" button → `Share.share(bulkExport(...))`; disabled when N == 0.
- Export screen reachable from `SessionHistoryScreen`'s app bar
  (share/export icon); route added if `lib/app.dart` uses named routes.
- `flutter test` fully green.

## Test plan

RED before implementation, in new `test/services/export_service_test.dart`
and `test/screens/export_screen_test.dart`:

- `sessionToMarkdown renders header, goal, duration, stars, and drills`
- `sessionToMarkdown renders ★★★★☆ for score 4`
- `sessionToMarkdown numbers only answered reflection questions`
- `sessionToMarkdown omits player/coach lines when empty`
- `legacy session with empty goal and null intensity exports without error`
- `bulkExport filters by inclusive date range`
- `bulkExport orders sessions chronologically and reports count`
- `bulkExport with empty range returns header with zero count`
- `export screen shows session count for selected range`
- `export button disabled when no sessions in range`

(`Share.share` itself is not unit-tested — keep it behind a thin call so the
screen test can verify the button state without invoking the platform channel.)

## Implementation plan

1. `pubspec.yaml`: add `share_plus` (latest major compatible with SDK
   ^3.11.1; plan doc's ^7.0.0 is a floor, use current stable) →
   `flutter pub get`.
2. `lib/services/export_service.dart`: pure static methods; star helper
   `String _stars(int n) => '★' * n + '☆' * (5 - n)`; reflection decoding via
   `decodeReflectionAnswers`; `DateFormat('EEE, d MMM yyyy')` from `intl`.
3. `lib/screens/train/log_session_screen.dart`: app-bar
   `actions: [if (_isEditing) IconButton(Icons.ios_share, onPressed: _share)]`.
4. `lib/screens/export_screen.dart`: StatefulWidget; two `ListTile` date
   pickers; `Consumer<SessionProvider>` for the count; share on tap.
5. `lib/screens/train/session_history_screen.dart`: app-bar action pushing
   `ExportScreen`; register route in `lib/app.dart` only if it has a route
   table (verify at implementation time).
6. Full `flutter test`.
