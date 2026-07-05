# Use case: flutter-bug-batch

**Status:** done (TASK-001 → TASK-004, completed 2026-07-05)
**Created:** 2026-07-05
**Source:** `badminton_flutter/docs/codebase-review-2026-07-05.md` §1 (pool idea #1)

## Problem

The 2026-07-05 codebase review found eight correctness bugs in the Flutter app.
Individually small, together they make the app untrustworthy for real daily use:
stats are polluted by demo data, photos silently break, a saved profile can
display blank, and tournaments are undeletable.

## Target users

The player and parent using the app daily on a real device (not the web demo).

## Desired outcome

All eight review findings fixed and covered by tests where the logic is
testable. Concretely, after this batch:

| ID | Fix | Acceptance |
|----|-----|-----------|
| B1 | Profile photo renders on device (`FileImage` for local paths; `NetworkImage` only on web) | Avatar shows the picked photo on iOS/Android |
| B2 | Profile form reliably shows the saved profile (subscribe to provider; don't clobber in-flight edits) | Fresh app start → Profile tab shows saved values; editing survives dependency changes |
| B3 | Demo data seeds once, behind a prefs flag; deleting it doesn't resurrect it | Empty DB after user deletion stays empty across restarts |
| B4 | Session photos copied to app documents dir; thumbnail shown on session card | Photo persists across restarts and is visible in history |
| B5 | Progress screen shows correctly-labelled streak (compute true best streak, show both) | "Current streak" and "Best streak" both correct on seeded fixtures |
| B6 | Tournament delete available in UI (with confirm); match delete gets a confirm | Both destructive actions confirm, then persist |
| B7 | Pull-to-refresh actually reloads from DB | `refresh()` bypasses the `_loaded` guard |
| B8 | `PRAGMA foreign_keys = ON` set in `onConfigure` | Pragma verified in a DB test |

## Constraints

- No behaviour changes beyond the fixes; no refactors that widen the diff.
- Tests must run headless via `flutter test` (sqflite needs
  `sqflite_common_ffi` as a dev dependency for unit tests).
- Keep web (`kIsWeb`) behaviour working — it's the preview channel.

## Open questions

None blocking. One decision folded in: B5 shows *both* current and best streak
(cheap once the calculation is extracted and tested).

## Implementation sketch

Group into 4 tasks by file locality (see /plan output):
data layer (B3, B7, B8) → profile screen (B1, B2) → session photos (B4) →
tournaments + progress labels (B5, B6).

## Relevant domains

None requiring external research — all fixes use dependencies already in
`pubspec.yaml` (`path_provider`, `sqflite`, `provider`, `shared_preferences`).
