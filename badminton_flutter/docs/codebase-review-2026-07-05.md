# Codebase review — badminton_flutter

**Date:** 2026-07-05
**Scope:** full `lib/` + `test/` (~4,000 lines), reviewed for correctness,
fit-for-purpose (a real junior player + parent using it daily), and ease of use.

Overall: a clean, well-organised MVP. Consistent layering (models → services →
providers → screens), sensible theming, good empty states. The issues below are
mostly "demo scaffold vs daily-use app" gaps, plus a handful of real bugs.

---

## 1. Bugs (correctness)

### B1 — Profile photo broken on device
`profile_screen.dart:118` uses `NetworkImage(_photoPath!)` for a **local file
path** returned by image_picker. That only renders on web; on iOS/Android the
avatar silently fails. Needs `FileImage(File(path))` (keep NetworkImage under
`kIsWeb`).

### B2 — Profile form can show blank even when a profile is saved
`profile_screen.dart:30–46`: the form is populated in `didChangeDependencies`
via `context.read` (no subscription), but the profile loads **async after
mount** (`MainShell` post-frame → `loadProfile`). All four tabs are built
eagerly in an `IndexedStack`, so the Profile tab captures the empty default
profile and never repopulates when loading completes. Bonus hazard: any
inherited-widget change re-runs `_loadFromProvider()` and can wipe in-flight
edits while `_editing == true`.

### B3 — Sample data reseeds forever and pollutes real stats
`main.dart:14–18` seeds 18 fake sessions **whenever the DB is empty**, not once.
A real user who deletes the demo data gets it back on next launch; until then
streaks, charts, and "this week" counts are fiction. Needs a `seeded` flag in
prefs (or an explicit in-app "load demo data" action) and ideally a "clear demo
data" affordance.

### B4 — Session photos are write-only and point at a temp directory
`log_session_screen.dart:44` stores the image_picker cache path — iOS purges
that cache, so the path goes stale. And `photoPath` is never rendered anywhere
(`session_card.dart` ignores it). Fix: copy the file into the app documents dir
(path_provider is already a dependency) and show a thumbnail on the session
card / a viewer on tap.

### B5 — "Best streak" is actually the current streak
`progress_screen.dart:37` labels `provider.currentStreak` as "Best streak".
Either compute a true max-streak over history or relabel to "Current streak".

### B6 — Tournaments cannot be deleted from the UI
`TournamentProvider.deleteTournament` (tournament_provider.dart:24) has **no
call site** — dead code path, and a stuck UX (a mistyped tournament is
permanent). Also inconsistent: deleting a *match* (tournament_screen.dart:191)
fires instantly with no confirmation, while sessions get a confirm dialog.

### B7 — Pull-to-refresh is a no-op
`home_screen.dart:38` wires `RefreshIndicator` to `loadSessions()`, which
early-returns after first load (`_loaded` guard, session_provider.dart:12).
Either add a `refresh()` that bypasses the guard or drop the indicator.

### B8 — FK cascade declared but never enabled
`database_service.dart:58` declares `ON DELETE CASCADE`, but sqflite requires
`PRAGMA foreign_keys = ON` per connection (via `onConfigure`). Harmless today
(deleteTournament deletes matches manually) — but it's a trap for the next
table. Enable the pragma or drop the FK clause.

## 2. Fit for purpose

- **No session editing** — delete-and-retype is the only correction path.
  Already specced as Part A3 of `docs/log-session-improvement-plan.md`; this
  review just raises its priority: it's the most common real-world need.
- **No backup / export** — all history lives in one sqflite file; a lost or
  reset phone erases years of training logs. The improvement plan's Markdown
  export helps AI analysis but isn't a backup; add a JSON/CSV export-share and
  (later) an import.
- **Drills stored comma-joined** (`session.dart:45`) — safe with today's fixed
  chips, but the improvement plan adds *custom drill tags*; a tag containing a
  comma corrupts the round-trip. Switch to JSON encoding before Part A lands.
- **Match scores are free text** — "21-15, 21-18" is convention only; garbage
  in, garbage rendered. Light validation (regex per set) would keep tournament
  stats meaningful.
- **Only a placeholder test** (`test/widget_test.dart`). The riskiest logic is
  exactly the untested kind: streak date-math, week bucketing, model ↔ map
  round-trips. These are pure functions — cheap, high-value tests.

## 3. Ease of use

- **Quick-log**: most training sessions repeat (same drills, same duration).
  A "repeat last session" prefill — or drill chips ordered by recent use —
  would cut logging to two taps. Biggest UX win for a 12-year-old's patience.
- **Profile edit has no cancel** — the only exits are Save or navigate away
  (which silently keeps unsaved edit state). Add Cancel to revert.
- **Technique library**: no text search (only category chips); level selector
  always starts at Beginner (could remember last choice or derive from
  profile); "Related Drills" chips are inert — linking them into the log
  screen would connect Learn → Train.
- **Duplicated delete flows**: session delete exists as swipe *and* icon with
  two copies of the same dialog (session_history_screen.dart:48–93) —
  consolidate into one helper.
- **No dark mode** — theme is hardcoded light; Material 3 makes a dark scheme
  nearly free via `ColorScheme.fromSeed(brightness: dark)`.

## 4. Nice-to-have ideas (fed into ideas/pool.md)

1. **Drill ↔ technique linkage** — "You practised Smash 12× this month" on the
   technique page; tap a logged drill chip to open its technique.
2. **Achievements / personal bests** — first 5-day streak, longest session,
   10-session month. Age-appropriate motivation; the streak badge already
   points this direction.
3. **Training reminders** — local notifications on scheduled training days.
4. **Per-opponent record** — repeat rivals are a big deal at junior level;
   the data (opponent name per match) is already captured.
5. **BadmintonTrack-12 hook** — attach the CV coach report (Markdown) to a
   session/match once that tool exists (already in the pool).

## 5. Suggested order

1. Bug batch B1–B8 (small, mostly one-liners; B2/B3/B4 are the real ones)
2. Test foundation for streak/week/serialisation logic
3. Existing improvement plan Part A (session editing + reflection + export),
   with the comma-join fix folded in
4. Quality-of-life batch (quick-log, search, cancel-edit, dark mode)
5. Nice-to-haves as separate pool ideas
