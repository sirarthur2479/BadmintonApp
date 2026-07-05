# Idea Pool

Entries are picked up by `/intake`. Status: (blank) = unprocessed, in-progress, done.

## Priority order

Ordered by dependency first, then value/effort. `/intake` should offer items in
this order unless the owner overrides.

| # | Idea | Why this position |
|---|------|-------------------|
| 1 | Flutter app bug batch (B1–B8) | Small, mechanical; restores trust in data (fake seeds, broken photos) before anything is built on top |
| 2 | Flutter app test foundation | Cheap; prerequisite safety net for the Part A refactor |
| 3 | Log-session improvement plan (Part A) + comma-safe drills | Already specced; session editing is the most-wanted daily feature; markdown export is a prerequisite for AI analysis features |
| 4 | BadmintonTrack-12 core (standalone CLI) | Independent Python track — can run in parallel with 1–3; prerequisite for #6 |
| 5 | Self-hosted backend (accounts/players API) | Already specced in docs; gives the app a home server — the natural host for #6's analysis service |
| 6 | BadmintonTrack-12 in-app integration (WiFi upload → home server) | Depends on #4 (pipeline) and benefits from #5 (server + auth); the end-state UX |
| 7 | Flutter app quality-of-life batch | Anytime filler; no dependencies, lower value per item |
| 8 | Audio session logging (local STT for spoken notes) | Anytime filler; no dependencies, small/self-contained, reuses a proven external pattern |

---

## 1. Flutter app bug batch (2026-07-05 review, B1–B8)

- **Added:** 2026-07-05
- **Status:** done (TASK-001 → TASK-004, 2026-07-05)
- **Source:** `badminton_flutter/docs/codebase-review-2026-07-05.md` §1
- **Summary:** Eight correctness fixes: device-broken profile photo
  (NetworkImage on a file path), profile form blank on first visit (async load
  vs didChangeDependencies), demo data reseeding forever and polluting real
  stats, write-only session photos stored in a purgeable temp dir, "Best
  streak" mislabel, no UI path to delete a tournament (dead provider method) +
  unconfirmed match delete, no-op pull-to-refresh, FK cascade without
  `PRAGMA foreign_keys`. Small and mechanical — one task, high priority.

## 2. Flutter app test foundation

- **Added:** 2026-07-05
- **Status:** done (TASK-005 → TASK-006, 2026-07-05)
- **Source:** `badminton_flutter/docs/codebase-review-2026-07-05.md` §2
- **Summary:** Replace the placeholder test with unit tests for the pure logic
  that actually breaks: streak date-math, week bucketing, model ↔ map
  round-trips (sessions, tournaments, matches, profile). Prerequisite for the
  log-session improvement plan work.

## 3. Log-session improvement plan (Part A) + comma-safe drills

- **Added:** 2026-07-05
- **Status:** done (TASK-007 → TASK-013, 2026-07-05)
- **Source:** `badminton_flutter/docs/log-session-improvement-plan.md` (existing
  spec) + review §2
- **Summary:** Implement the already-written plan: session editing, goal +
  reflection fields, Markdown export for AI analysis. Fold in the storage fix:
  drills move from comma-joined string to JSON before custom drill tags land.

## 4. BadmintonTrack-12 — CV + local-LLM video analysis tool (standalone)

- **Added:** 2026-07-05
- **Status:** in progress (use-case: `ideas/use-cases/badmintontrack-12.md`)
- **Source:** owner prompt (full spec in `ideas/use-cases/badmintontrack-12.md`)
- **Summary:** Python tool that processes 1080p60 iPhone footage of a 12-year-old
  regional player: court homography + footwork recovery metrics (rear view),
  joint-angle biomechanics (side view), and a local-LLM coach narrative engine
  that turns the telemetry into age-appropriate training directives. Outputs a
  Markdown report compatible with the badminton_flutter match-log / AI-analysis
  export format. Runs as a CLI on the owner's computer; footage arrives by
  manual copy in this phase (idea #6 removes that step).

## 5. Self-hosted backend — accounts, players, data API

- **Added:** 2026-07-05 (spec pre-dates the pool)
- **Status:**
- **Source:** `badminton_flutter/docs/self-hosting-plan.md` +
  `self-hosting-setup.md` (complete spec: FastAPI + SQLite + JWT,
  account → players model, Docker Compose, Cloudflare Tunnel)
- **Summary:** Self-host the app at home with persistent multi-user storage.
  Listed in the pool so its priority is explicit: it precedes idea #6 because
  the same home server (and its auth) should host the video-analysis service.

## 6. BadmintonTrack-12 in-app integration — WiFi upload to home analysis server

- **Added:** 2026-07-05
- **Status:**
- **Depends on:** #4 (analysis pipeline must exist), ideally #5 (server + JWT)
- **Summary:** Close the loop so no file is ever copied manually: record video
  on the phone → the app uploads it to an analysis server running on the
  owner's computer → the BadmintonTrack-12 pipeline (CV + Ollama) runs as a
  background job → the coach report lands back in the app attached to the
  session/match log.
- **Key constraints from the owner:**
  - **WiFi-only upload, never cellular** — enforce via `connectivity_plus`
    (queue the upload and auto-start when WLAN is available). Motivated by
    both bandwidth (a 10-min 1080p60 clip is roughly 1–2 GB) and privacy.
  - **Privacy:** footage of a minor must not transit the internet. The upload
    endpoint must be LAN-only — reachable on the home network directly, and
    explicitly NOT routed through the Cloudflare Tunnel that exposes the rest
    of the app. Server discovery via manual IP/port in settings first (mDNS
    later).
- **Sketch:** chunked/resumable upload endpoint (FastAPI) → job queue with
  states (queued / analyzing / done / failed) → app polls job status → report
  (Markdown + court-map image) stored per session. Analysis takes minutes, so
  the UX is fire-and-forget with a status card, not a spinner.
- **Open questions:** delete video from phone after successful upload?
  retention policy on the server? which video length/framerate to encourage at
  record time?

## 7. Flutter app quality-of-life batch

- **Added:** 2026-07-05
- **Status:**
- **Source:** `badminton_flutter/docs/codebase-review-2026-07-05.md` §3–4
- **Summary:** Quick-log ("repeat last session" prefill), profile edit Cancel,
  technique library text search + drill↔technique linking, consolidated delete
  dialog, dark mode, achievements/personal bests, training reminders,
  per-opponent record. Split at /plan time; not all need to ship together.

## 8. Audio session logging — local STT for spoken session notes

- **Added:** 2026-07-05
- **Status:**
- **Source:** `research/local-llm-voice-chatbot-reference.md` (ported from a
  sibling project's local-LLM voice chatbot investigation)
- **Summary:** Let the parent/coach speak notes during or after a session
  instead of typing them, transcribed fully locally (ffmpeg → 16kHz mono WAV →
  `faster-whisper`, CPU `int8`, no cloud) and attached to the session log.
  Reuses a small, proven, dependency-light pattern (`utils/stt.py` in the
  reference doc) rather than building STT from scratch. Independent of
  BadmintonTrack-12 (audio only, no video/CV) — could land in either
  `badminton_flutter` or `badminton_track`.
- **Open questions:** which app owns it — a recording button in
  `badminton_flutter`'s session UI, or a small utility in `badminton_track`?
  Transcribe on-device (phone) or record-then-transcribe on the owner's
  computer? Whole-utterance transcription (as in the reference) is simplest
  for MVP — no VAD/chunking needed unless notes run long.
