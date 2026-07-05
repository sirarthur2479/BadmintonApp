# Idea Pool

Entries are picked up by `/intake`. Status: (blank) = unprocessed, in-progress, done.

---

## BadmintonTrack-12 — CV + local-LLM video analysis tool

- **Added:** 2026-07-05
- **Status:**
- **Source:** owner prompt (full spec in `ideas/use-cases/badmintontrack-12.md`)
- **Summary:** Python tool that processes 1080p60 iPhone footage of a 12-year-old
  regional player: court homography + footwork recovery metrics (rear view),
  joint-angle biomechanics (side view), and a local-LLM coach narrative engine
  that turns the telemetry into age-appropriate training directives. Outputs a
  Markdown report compatible with the badminton_flutter match-log / AI-analysis
  export format.

---

## Flutter app bug batch (2026-07-05 review, B1–B8)

- **Added:** 2026-07-05
- **Status:**
- **Source:** `badminton_flutter/docs/codebase-review-2026-07-05.md` §1
- **Summary:** Eight correctness fixes: device-broken profile photo
  (NetworkImage on a file path), profile form blank on first visit (async load
  vs didChangeDependencies), demo data reseeding forever and polluting real
  stats, write-only session photos stored in a purgeable temp dir, "Best
  streak" mislabel, no UI path to delete a tournament (dead provider method) +
  unconfirmed match delete, no-op pull-to-refresh, FK cascade without
  `PRAGMA foreign_keys`. Small and mechanical — one task, high priority.

## Flutter app test foundation

- **Added:** 2026-07-05
- **Status:**
- **Source:** `badminton_flutter/docs/codebase-review-2026-07-05.md` §2
- **Summary:** Replace the placeholder test with unit tests for the pure logic
  that actually breaks: streak date-math, week bucketing, model ↔ map
  round-trips (sessions, tournaments, matches, profile). Prerequisite for the
  log-session improvement plan work.

## Log-session improvement plan (Part A) + comma-safe drills

- **Added:** 2026-07-05
- **Status:**
- **Source:** `badminton_flutter/docs/log-session-improvement-plan.md` (existing
  spec) + review §2
- **Summary:** Implement the already-written plan: session editing, goal +
  reflection fields, Markdown export for AI analysis. Fold in the storage fix:
  drills move from comma-joined string to JSON before custom drill tags land.

## Flutter app quality-of-life batch

- **Added:** 2026-07-05
- **Status:**
- **Source:** `badminton_flutter/docs/codebase-review-2026-07-05.md` §3–4
- **Summary:** Quick-log ("repeat last session" prefill), profile edit Cancel,
  technique library text search + drill↔technique linking, consolidated delete
  dialog, dark mode, achievements/personal bests, training reminders,
  per-opponent record. Split at /plan time; not all need to ship together.
