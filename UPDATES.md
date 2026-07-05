# Updates

## 2026-07-05

| Task | Summary |
|---|---|
| TASK-001 | Data layer fixes: FK pragma on (B8), demo data seeds once behind prefs flag (B3), real pull-to-refresh (B7); headless sqflite_common_ffi test infra added (9 tests green) |
| TASK-002 | Profile screen fixes: FileImage avatar on device with web-safe conditional import (B1); form syncs from provider without clobbering edits (B2) |
| TASK-003 | Session photos persist to app documents dir with relative paths, delete with their session, and display as tap-to-view thumbnails on session cards (B4) |
| TASK-004 | Tournament delete added to UI, match delete confirms, shared confirmDelete helper (B6); streak math extracted to pure tested utils, Progress shows current + best streak (B5). Closes the B1-B8 bug batch |
| TASK-005 | Model round-trip test coverage added for `TrainingSession`, `Tournament`/`TournamentMatch`, and `PlayerProfile` (`test/models/`) — comma/pipe-join, nullable fields, and default fallback all characterized. 42/42 suite green, no production changes |
