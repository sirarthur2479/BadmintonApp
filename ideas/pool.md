# Idea Pool

Entries are picked up by `/intake`. Status: (blank) = unprocessed, in-progress, done.

## North star (2026-07-12)

One idea underneath every feature here: **a player development record that an
AI coach reads and writes.** Four verbs in a loop:

1. **Capture** — session logs (done), drill videos (done), per-point match
   clips (#10), spoken notes (#8), match reflections (#9).
2. **Analyze** — CV pipelines turn each capture into facts (footwork metrics,
   joint angles, two-player movement, later shuttle/rally events); STT turns
   voice into structured notes.
3. **Remember** — a persistent development record per player, plus scouting
   profiles per opponent. Every analyzer writes facts into it; reports stop
   being one-offs.
4. **Advise** — the local LLM reads the *accumulated* record: post-game
   reports, trend reviews, drills targeted at recurring mistakes, pre-match
   scouting on known opponents.

"Remember" is what a real coach does that no single-video tool can — and it's
the part of the owner's manual post-game routine still living in their head.

Delivery stays sliced (one pool idea at a time, as ever), but one thing gets
designed once, up front: the **record's data model** — a facts store (player
facts, opponent facts; each with source, date, confidence) that footwork,
biomech, match analysis, and voice notes all write into and the coach module
reads from. That design is stage 0 of #10's intake; without it each pipeline
keeps emitting disconnected one-off summaries and there is no memory.

## Priority order

Ordered by dependency first, then value/effort. `/intake` should offer items in
this order unless the owner overrides.

| # | Idea | Why this position |
|---|------|-------------------|
| 1 | Flutter app bug batch (B1–B8) | done |
| 2 | Flutter app test foundation | done |
| 3 | Log-session improvement plan (Part A) + comma-safe drills | done |
| 4 | BadmintonTrack-12 core (standalone CLI) | done |
| 5 | Self-hosted backend (accounts/players API) | done |
| 6 | BadmintonTrack-12 in-app integration (WiFi upload → home server) | done |
| 9 | Match-log feature (per-match reflection log) | **Next.** The development record's human-authored layer and the UI surface #10 attaches clips/reports/profiles to; already part-built, needs rework onto the multi-player architecture. Doing it first avoids building #10 against the wrong surface |
| 8 | Audio session logging (local STT for spoken notes) | Small and self-contained; lands the voice-capture path #10 phase 1 uses for per-point notes. Can also run as filler in parallel with #9 |
| 10 | Match-point analysis & opponent profiling | The centrepiece. Stage 0 = design the shared development-record schema (north star above); phase 1 (two-player tracking + human tags + opponent profiles) needs no new CV research; phase 2 (shuttle tracking) gated on a `/research` pass **and** on manual validation of the existing pipeline with real footage first |
| 7 | Flutter app quality-of-life batch | Anytime filler; no dependencies, lower value per item. Note: its "per-opponent record" item is superseded by #10's opponent profiles |

Cross-cutting gate: before investing in #10 phase 2, run the **manual test
pass** of the existing pipeline (real footage through CLI → server → app; see
2026-07-12 session findings: track README missing, Docker image can't run the
pipeline, calibration path coupling) — it validates the CV foundation
everything above builds on.

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
- **Status:** done (TASK-014 → TASK-020, 2026-07-05)
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
- **Status:** done (TASK-021 → TASK-027, 2026-07-06)
- **Source:** `badminton_flutter/docs/self-hosting-plan.md` +
  `self-hosting-setup.md` (complete spec: FastAPI + SQLite + JWT,
  account → players model, Docker Compose, Cloudflare Tunnel)
- **Summary:** Self-host the app at home with persistent multi-user storage.
  Listed in the pool so its priority is explicit: it precedes idea #6 because
  the same home server (and its auth) should host the video-analysis service.

## 6. BadmintonTrack-12 in-app integration — WiFi upload to home analysis server

- **Added:** 2026-07-05
- **Status:** done (TASK-028 → TASK-034, 2026-07-08; use-case: `ideas/use-cases/badmintontrack-integration.md`)
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

## 9. Match-log feature — per-match reflection log

- **Added:** 2026-07-12
- **Status:**
- **Source:** built independently on `A2-remote-signin-improve-log-feature`
  before that branch was rebased onto main; recovered from the stash diff
  during the rebase and parked here rather than merged, since main had since
  grown a conflicting multi-player architecture. The branch's own duplicate
  backend (`badminton-server/`, a weaker fork of `badminton_backend` using the
  CVE-flagged `python-jose`/`passlib` pair TASK-021 explicitly rejected) and
  duplicate `auth_service.dart`/`api_service.dart` were discarded outright —
  not part of this idea.
- **Summary:** A standalone, richer per-match log distinct from the existing
  `Tournament`-scoped `matches` (opponent/score/isWin). Model fields covered
  pre-match gameplan/readiness, post-match move-by-move performance notes, and
  video references — not tied to a `tournamentId`. UI was `train_screen.dart`,
  a tab container meant to replace `session_history_screen.dart` in the Train
  tab with two sub-tabs: Sessions (existing) and Match Logs (new). Supporting
  pieces: `match_log.dart` model, `match_log_provider.dart`,
  `log_match_screen.dart`, `match_log_card.dart` widget. Also bundled two
  unrelated widgets built alongside it — `youtube_player_widget.dart` (inline
  technique video playback) and `markdown_export_service.dart` (export a
  match log to Markdown, mirroring #3's session export) — worth splitting out
  since they don't depend on the match-log data model.
- **Rework needed before landing:** the old branch had no `PlayerProvider`/
  `PlayerSelectScreen` awareness (single-player mental model predating #5).
  To integrate: scope `MatchLog` by player (same pattern as
  `SessionProvider`/`TournamentProvider`), add a `match_logs` table +
  `/players/{id}/match-logs` routes to `badminton_backend` mirroring the
  sessions routes (TASK-023/026 pattern), add matching `ApiService` methods,
  wire `MatchLogProvider` to construct via `ApiService` on web like
  `SessionProvider` does, and merge `TrainScreen` into `MainShell` in place of
  `SessionHistoryScreen` without breaking main's player-select routing.

## 10. Match-point analysis & opponent profiling — replace the manual post-game review

- **Added:** 2026-07-12
- **Status:**
- **Source:** owner, first real-usage review of the video analysis feature. The
  drill-benchmark workflow (#4/#6) forces training to fit the app; the owner's
  actual routine is the reverse — after every game they manually review 1–2
  minute clips of individual points/interactions to discuss the player's
  mistakes and the opponent's habits. This idea automates that routine.
- **Depends on:** #4 (pipeline) and #6 (upload/job loop), both done. #9
  (match log) should land first — it is the UI surface per-point clips,
  post-game reports, and opponent profiles attach to. Strong synergy with #8
  (local STT — spoken per-point notes) and the per-venue calibration friction
  found in the same review (tap-4-corners on a frame in the app would solve
  both).
- **Architecture principle (carried over from #4):** CV extracts verifiable
  facts; the local LLM reasons over facts, never raw video. Each phase widens
  the fact vocabulary.
- **Stage 0 — shared development-record schema (see north star):** design the
  facts store (player facts + opponent facts, each with source/date/
  confidence) that this and all other analyzers write into and the coach
  module reads from. Design once, before phase 1 emits its first report.
- **Phase 1 — human-in-the-loop, no new CV research:**
  - Track BOTH players (homography + feet projection already work for the far
    half): coverage, speed, recovery for player and opponent → opponent
    movement habits (slow corners, camping position, late-game fade) and the
    player's positional mistakes (out of position at rally end, short
    recovery).
  - Per-point clip upload (fits the existing queue; ~100–300 MB) with a
    one-tap tag (won/lost + reason category + opponent) and/or a spoken note
    transcribed locally (#8).
  - LLM merges tags/notes + two-player telemetry into a post-game report and
    a rolling **opponent profile** (new backend entity: accumulated stats +
    LLM-refreshed scouting card) plus the player's own profile.
- **Phase 2 — shuttle tracking (the big unlock, real research risk):**
  badminton-specific open-source prior art exists (TrackNet V2/V3, CNN
  heatmap tracker trained on rear-elevated broadcast footage; PyTorch, runs
  on Apple Silicon; amateur-footage domain gap may need fine-tuning →
  `/research` topic). Trajectory gives hit detection (direction reversals),
  coarse shot-type heuristics (smash/clear/drop/net from arc), rally tempo,
  and placement — respecting the court-plane invariant: only landing points
  (floor) and hitter's-feet-at-hit-time are projected, never mid-air shuttle
  positions. Output: a symbolic rally transcript the 8B model reasons over
  (serve placement distribution, patterns preceding lost points, weak wing).
  Phase 2 progressively automates what the human tags in phase 1.
- **Explicit non-goals (out of local reach):** automatic line calls, certain
  who-won-the-point, stroke-fault detection from the rear view, local VLMs
  watching clips directly (unreliable for fine sports judgment — later
  experiment at most).
- **Open questions:** opponent identity entry UX (name per clip? pick list?);
  where the rolling profiles live in the app UI; whether phase 1 tags are
  per-clip or per-session; retention policy for many small clips.
