# TASK-040 - LogMatchScreen create/edit form

**Use case:** [ideas/use-cases/match-log.md](../../ideas/use-cases/match-log.md)
**Research:** -
**Depends on:** TASK-038, TASK-039
**Effort:** M
**Risk:** low
**Status:** done

## Goal

The form that creates and edits a `MatchLog`, structured pre-match →
match → post-match, following `LogSessionScreen`'s conventions (edit mode
via an optional `existing` parameter, date picker, `StarRating`, save
through the provider).

## Acceptance criteria

- `lib/screens/train/log_match_screen.dart`:
  `LogMatchScreen({MatchLog? existing})`.
  - Context section: date picker (defaults today), opponent (required,
    validator), event context (free text), scores (free text), win/loss
    toggle (`SegmentedButton` or switch).
  - Pre-match section: gameplan (multiline), readiness (`StarRating`, 1–5,
    default 3).
  - Post-match section: performance notes (multiline), key moments
    (multiline), optional video reference (free text path/URL).
- Save: create mode → `addMatchLog` with a UUID id (same id source as
  sessions); edit mode → `updateMatchLog` preserving id; then pop.
- Opponent empty → validation error, no save.
- `MatchLogCard` tap opens the screen pre-filled in edit mode; FAB from
  TASK-039 opens create mode.
- `flutter analyze` clean; full suite green.

## Test plan (`test/screens/log_match_screen_test.dart`, RED first)

Pattern from `log_session_screen_test.dart`:
- `saving a filled form adds a match log to the provider`
- `opponent is required - empty shows validation error and does not save`
- `edit mode pre-fills fields from the existing log`
- `edit mode save calls updateMatchLog with the same id`
- `readiness stars default to 3`
- `win/loss toggle round-trips into the saved log`

## Implementation plan

1. RED widget tests as above.
2. Create `lib/screens/train/log_match_screen.dart` (form layout and
   section headers cloned in style from `log_session_screen.dart`).
3. Wire navigation: TASK-039's FAB → create mode; `MatchLogCard` tap →
   edit mode.
4. GREEN: targeted test file, then full `flutter test`.
