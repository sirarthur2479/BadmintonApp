# Use case: log-session-part-a

**Status:** planned (TASK-007 → TASK-013)
**Created:** 2026-07-05
**Source:** `badminton_flutter/docs/log-session-improvement-plan.md` (Parts A, D,
E — training-session scope only) + `badminton_flutter/docs/codebase-review-2026-07-05.md`
§2 comma-join fix (pool idea #3)

## Problem

Training-session logging is write-once and shallow:

- **No editing.** A typo'd or incomplete session can only be deleted and
  retyped. Session editing is the most common real-world need per the
  2026-07-05 codebase review.
- **No goal or reflection.** A session records date, duration, drills,
  intensity (1–5) and free notes. There's no way to capture *why* the session
  happened (goal), how close it came (achievement score), or structured
  reflection (player/coach remarks, guided questions) — the data a coach or an
  AI analysis actually needs.
- **No export.** History is locked inside sqflite on one phone. The planned AI
  analysis features (and plain sharing with a coach) need a clean Markdown
  export of sessions over a date range.
- **Fragile drill storage.** `TrainingSession.toMap` comma-joins drills
  (`session.dart:45`) and `fromMap` splits on `,`. Safe with today's fixed
  chips, but Part D adds *custom drill tags* — a tag containing a comma
  silently corrupts the round-trip. Storage must move to JSON encoding
  **before** custom tags land.

## Target users

The player (12-year-old regional junior) and the parent/coach who logs and
reviews sessions. The Markdown export additionally serves future AI-analysis
tooling (BadmintonTrack-12 report format is designed to be compatible).

## Desired outcome

Implement the training-session scope of the existing improvement plan:

1. **Session editing (plan A3)** — `LogSessionScreen` accepts an optional
   existing session, pre-populates, button becomes "Update";
   `updateSession` through `DatabaseService` + `SessionProvider`; edit button
   on `SessionCard` next to delete.
2. **Goal + reflection fields (plan A1/A2)** — new `ReflectionData` model with
   6 fixed questions (`kReflectionQuestions`); `TrainingSession` gains
   `sessionGoal`, `goalAchievementScore` (1–5, replaces intensity),
   `playerRemarks`, `coachRemarks`, `reflectionAnswersJson`, and `intensity`
   becomes nullable legacy. All new fields default in `fromMap` for
   backward compatibility.
3. **LogSessionScreen redesign (plan D)** — section order: date, session goal,
   drills (existing chips + custom tag add/long-press-delete), reflection
   (6 questions, goal-achievement stars, player/coach remarks), advanced
   (duration, collapsed), photos, save/update. Validation: non-empty goal +
   ≥1 drill.
4. **Markdown export (plan E, sessions only)** — `ExportService.sessionToMarkdown`
   in the plan's documented format; single-session share from edit mode
   (`share_plus`); bulk export screen with date range + preview count for
   training sessions.
5. **Comma-safe drills (review §2)** — `drills` serialized as a JSON array in
   the DB; migration converts existing comma-joined rows. Lands before/with
   custom tags.
6. **Supporting changes** — DB v1→v2 migration (new session columns,
   `custom_tags` table, drills JSON conversion), provider custom-tag CRUD +
   `allDrillTypes` + `avgGoalAchievementPerWeek`, `SessionCard` shows
   goal/stars/remarks, `goalScoreColor` in theme, goal-achievement 8-week
   chart on home screen replacing the intensity display on the last-session
   card.

Acceptance (from the plan's verification list, match items excluded):
fresh install works; v1 upgrade shows old sessions gracefully (empty goal,
default ★3, no crash, drills intact through the JSON conversion); edit
round-trip works; custom tags persist and are deletable; a tag containing a
comma survives save/reload; single + bulk Markdown export produce the
documented format; goal-achievement chart renders; `flutter test` stays green
(round-trip tests from TASK-005 updated for the new fields).

## Constraints

- **Out of scope:** all of plan Part B (Match Log), the match half of Part C
  (history filter toggle exists only if trivial; unified match+training list
  is Part B territory), match Markdown export, video referencing
  (`open_file`, `url_launcher`). These arrive with a later pool entry.
- Backward compatibility is mandatory: existing v1 rows (seeded and real)
  must load without crash and display sensibly.
- New deps limited to `share_plus` (export). `image_picker` and `fl_chart`
  already present.
- Existing model round-trip tests (TASK-005) guard `toMap`/`fromMap`; they
  must be extended, not bypassed — the drills JSON change deliberately breaks
  the old storage format, so migration + tests are part of the work.
- Offline/local only, as everywhere in this app.

## Open questions

None blocking. Judgment calls left to /plan:
- Whether the bulk-export screen ships in this batch or just single-session
  export (both are specced; bulk is what AI analysis wants).
- Whether legacy `intensity` still renders on old sessions' cards or is
  simply ignored once goal-achievement stars exist.
- Migration detail: convert drills column in-place during `onUpgrade` vs.
  tolerant dual-format `fromMap` (JSON-first, comma fallback). Plan doc is
  silent; in-place conversion + tolerant read is the safe combination.

## Implementation sketch

Phased per the plan's implementation order, restricted to training scope:

1. **Foundation** — `reflection_data.dart`, extend `session.dart`
   (new fields + JSON drills), DB v2 migration (`custom_tags`, new columns,
   drills conversion, `updateSession`), provider updates, `share_plus` dep.
2. **Widgets/theme** — `goalScoreColor`, `SessionCard` (goal, stars, remarks,
   edit button), `goal_achievement_chart.dart`.
3. **Screens** — `LogSessionScreen` redesign + edit mode, home screen
   last-session + trend chart, bulk export screen (if in).
4. **Export** — `export_service.dart` (sessions), share wiring.
5. **Seed + tests** — sample goals/reflections in seed data, extend
   round-trip/week-bucket tests, migration test.

## Relevant domains

None requiring external research — pure Flutter/Dart work fully specced in
`docs/log-session-improvement-plan.md`, with all techniques (sqflite
migration, provider state, `share_plus`) standard and already exemplified in
the codebase or trivially documented.
