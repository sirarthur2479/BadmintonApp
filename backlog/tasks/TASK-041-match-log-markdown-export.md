# TASK-041 - Match-log Markdown export

**Use case:** [ideas/use-cases/match-log.md](../../ideas/use-cases/match-log.md)
**Research:** -
**Depends on:** TASK-035, TASK-039
**Effort:** S
**Risk:** low
**Status:** todo

## Goal

Export a match log (or all of them) as Markdown for AI analysis, extending
`ExportService` (TASK-013 pattern) so match reflections reach the same
consumption path as session exports.

## Acceptance criteria

- `ExportService.matchLogToMarkdown(MatchLog log)`: a Markdown section with
  date (existing `_dateFmt`), opponent, event context, result (W/L +
  scores), gameplan, readiness as stars (`_stars(readinessScore)`),
  performance notes, key moments, and the video reference when present;
  empty optional fields are omitted, not rendered as blank headings.
- `ExportService.bulkExportMatchLogs({required List<MatchLog> logs})`
  (or extend the existing `bulkExport` signature if cleaner) concatenates
  newest-first with a document header, matching the session bulk-export
  shape.
- Surfaced in the UI: the Match Logs tab's app-bar export action (or card
  menu) copies/share-sheets the Markdown the same way session export does
  via `ExportScreen` — reuse, don't fork, the existing share/copy plumbing.
- `flutter analyze` clean; full suite green.

## Test plan (`test/services/export_service_test.dart` extend, RED first)

- `matchLogToMarkdown renders result line with W and scores`
- `matchLogToMarkdown renders readiness as five-slot stars`
- `matchLogToMarkdown omits empty optional sections`
- `matchLogToMarkdown includes video reference when set`
- `bulk export lists logs newest first under one header`

## Test plan (UI, extend `test/screens/train_screen_test.dart`)

- `export action on Match Logs tab produces markdown for current logs`

## Implementation plan

1. RED unit tests against `ExportService`.
2. Extend `lib/services/export_service.dart` with the two methods,
   reusing `_dateFmt` and `_stars`.
3. Wire the export entry point in `train_screen.dart` (reuse the
   `ExportScreen` flow if it generalizes cheaply; otherwise a direct
   share/copy action scoped to match logs).
4. GREEN: targeted tests, then full `flutter test`.
