# Updates

## 2026-07-05

| Task | Summary |
|---|---|
| TASK-001 | Data layer fixes: FK pragma on (B8), demo data seeds once behind prefs flag (B3), real pull-to-refresh (B7); headless sqflite_common_ffi test infra added (9 tests green) |
| TASK-002 | Profile screen fixes: FileImage avatar on device with web-safe conditional import (B1); form syncs from provider without clobbering edits (B2) |
| TASK-003 | Session photos persist to app documents dir with relative paths, delete with their session, and display as tap-to-view thumbnails on session cards (B4) |
| TASK-004 | Tournament delete added to UI, match delete confirms, shared confirmDelete helper (B6); streak math extracted to pure tested utils, Progress shows current + best streak (B5). Closes the B1-B8 bug batch |
| TASK-005 | Model round-trip test coverage added for `TrainingSession`, `Tournament`/`TournamentMatch`, and `PlayerProfile` (`test/models/`) — comma/pipe-join, nullable fields, and default fallback all characterized. 42/42 suite green, no production changes |
| TASK-006 | `sessionsPerWeek`/`avgIntensityPerWeek` take an injectable `now:` param for deterministic week-boundary/empty-week/averaging tests; removed the counter-app placeholder `widget_test.dart`. Closes the flutter-test-foundation use-case. 46/46 suite green |
| TASK-007 | Session model Part A foundation: drills stored as JSON array (comma-safe custom tags, legacy comma rows still readable), new `ReflectionData` module (6 fixed questions + tolerant JSON encode/decode), `TrainingSession` gains goal/reflection fields with backward-compatible defaults, `intensity` now nullable legacy. Fresh-install schema updated — v1 devices need TASK-008's migration. 60/60 suite green |
| TASK-008 | DB schema v2: `onUpgrade` rebuilds sessions table in a transaction (comma drills → JSON, intensity nullable, goal/reflection columns defaulted) — verified against a real v1 db file; `updateSession` UPDATE path and `custom_tags` table with idempotent CRUD, both with web in-memory branches. 68/68 suite green |
| TASK-009 | `SessionProvider.updateSession` (persists, re-sorts by date, notifies), custom-tag state (`customTags`/`allDrillTypes`, trim + blank/dup/built-in guards, loaded with `refresh()`), and `avgGoalAchievementPerWeek` via a shared `_avgPerWeek` helper that also makes `avgIntensityPerWeek` skip unrated sessions. 79/79 suite green |
| TASK-010 | Session editing end-to-end: `LogSessionScreen` edit mode (prefill incl. non-built-in drills, Update button, id preserved, photo re-copied only when changed with old file cleanup), `SessionCard` edit icon, history screen wiring. 87/87 suite green |
| TASK-011 | Log-session form redesign: goal field + 6-question reflection + `StarRating` goal-achievement score replacing the intensity slider (new sessions save null intensity, edits keep legacy), duration + notes demoted to collapsed Advanced, goal+drill validation, custom drill tag chips (add dialog, long-press delete for user tags only). 100/100 suite green |
