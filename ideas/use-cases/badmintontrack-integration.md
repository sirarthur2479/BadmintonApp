# Use case: badmintontrack-integration

**Status:** planned (TASK-028 → TASK-034)
**Created:** 2026-07-06
**Source:** owner prompt, pool idea #6 (`ideas/pool.md` §6). Depends on and
integrates two already-shipped pieces: `badminton_track/` (pool #4 — CV +
local-LLM analysis CLI) and `badminton_backend/` (pool #5 — self-hosted
FastAPI + SQLite + JWT API). Both are done, so this idea is now fully
unblocked.

## Problem

BadmintonTrack-12 (pool #4) works, but only as a CLI the owner runs by hand
after manually copying footage off the phone. The self-hosted backend
(pool #5) now exists and gives the app a home server. This idea closes the
loop: record on the phone → the app uploads over the home WiFi → the
existing CV/LLM pipeline runs as a background job on the server → the coach
report and court-map image land back in the app, attached to the training
session they belong to. No more manual file copying, no cloud upload of a
minor's footage.

## Target users

- The player (records video during/after training)
- The parent/coach (owns the account, reviews the coach report once it's
  ready)

## Desired outcome

1. **Recording → queued upload.** The app records or picks a video for a
   training session and queues it for upload. Upload only starts (and only
   continues) while on WiFi — never cellular — using `connectivity_plus`
   (per the owner's explicit constraint) to gate a resumable upload; the
   queue survives app restarts and WiFi drops mid-transfer.
2. **LAN-only ingest.** The upload endpoint runs on the home server but is
   **not** reachable through the Cloudflare Tunnel that exposes the rest of
   the app to the internet — footage of a minor must stay on the LAN.
   Server address (IP:port) is entered once in app settings (manual entry
   for MVP; mDNS discovery is a later idea, not in scope here).
3. **Background analysis job.** Once a video finishes uploading, the server
   enqueues a job that runs the existing `badminton_track` pipeline
   (`footwork.run_footwork` / `biomech.run_biomech` + `coach.produce_report`,
   per the mode the owner selects) against it. Job states: `queued` →
   `analyzing` → `done` | `failed`, persisted so a server restart doesn't
   lose in-flight jobs.
4. **Fire-and-forget UX.** The app shows a status card on the session (not a
   blocking spinner) and polls job status; when `done`, the Markdown coach
   report and court-map image are stored against that session and become
   part of its normal detail view / export.
5. **Ownership scoping.** Uploads and jobs are scoped to the uploading
   account's player, reusing the JWT auth and `require_player` pattern
   already built in `badminton_backend/`.

Success = record a clip on the phone at home → within a few minutes (no
manual steps) the session shows an attached coach report and court map,
without the video ever leaving the LAN or a byte moving over cellular.

## Constraints

- **WiFi-only, always** (owner constraint, non-negotiable): enforce with
  `connectivity_plus`; an in-flight upload pauses immediately on WiFi loss
  and resumes automatically when WiFi returns — never falls back to
  cellular.
- **LAN-only ingest** (owner constraint, non-negotiable): the upload
  endpoint must be unreachable via the public Cloudflare Tunnel path. In the
  existing `deploy/docker-compose.yml`, the tunnel only fronts nginx:80; the
  upload service must bind a **separate port** (e.g. 8001) that is not
  proxied by nginx and is only exposed on the LAN interface / bridge
  network — reachable at `http://<lan-ip>:8001` but never through
  `https://badminton.yourdomain.com`.
- **Large files over an unreliable link:** a 10-minute 1080p60 clip is
  ~1–2 GB; mobile WiFi drops mid-transfer are expected and must not restart
  the upload from zero. Needs a genuinely resumable/chunked protocol, not a
  single `POST` of the whole file.
- **Analysis is CPU/GPU-heavy and slow** (minutes per video, per the
  existing pipeline). The server is a single Docker Compose host with no
  Redis/Celery infrastructure today — job orchestration must fit that
  (in-process queue + SQLite-persisted state, not a new infra dependency)
  while still surviving a container restart mid-job (mark as `failed`,
  don't hang forever).
- **badminton_track's heavy ML deps stay optional** (per its own
  `pyproject.toml` extras). The backend must not force-install
  ultralytics/mediapipe/ollama just to serve auth/players/sessions; the job
  runner imports `badminton_track` lazily and reports an actionable error
  (extras missing) into the job's `failed` state rather than crashing the
  server process.
- Privacy invariants from both parent projects carry over: no cloud APIs,
  videos/analysis artifacts stay local, existing gitignore rules for
  `videos/`, `data/`, `output/` apply to whatever directory the backend
  lands uploads in.
- Mobile-only feature: web has no camera/background-upload story and
  already has no video pipeline; this entire flow is gated to non-web
  builds, same pattern as existing mobile-only code paths.

## Open questions

None block starting (MVP defaults below; revisit once the flow is used for
real):

1. **Delete video from phone after successful upload?** MVP default: no —
   keep it on the phone, let the owner delete manually. Auto-delete is a
   small follow-up once trust in the upload path is established.
2. **Retention policy on the server?** MVP default: keep uploaded videos
   indefinitely next to the SQLite DB (same "it's one directory, back it up"
   posture as the existing backend). A pruning job is a later idea.
3. **Which video length/framerate to encourage at record time?** MVP
   default: no enforced limit; reuse the existing pipeline's documented
   assumption (1080p60, up to ~10 minutes) as in-app guidance text, not a
   hard cap.

## Implementation sketch (staging for /plan)

- **Stage 1 — Upload protocol + LAN-only endpoint:** resumable/chunked
  upload API on the backend (new port, not tunneled), with a Flutter client
  that can pause/resume across WiFi drops and app restarts.
- **Stage 2 — WiFi gating:** `connectivity_plus`-driven queue on the Flutter
  side — never starts or continues an upload off WiFi.
- **Stage 3 — Job queue + pipeline invocation:** persisted job records
  (queued/analyzing/done/failed), an in-process worker that lazily calls into
  `badminton_track`, writes the Markdown report + court-map image path back
  onto the job row.
- **Stage 4 — Session attachment + status UI:** job status polling, report/
  court-map surfaced on the training session (detail view + export),
  fire-and-forget status card instead of a spinner.
- **Stage 5 — Settings + server discovery (manual):** app settings screen
  for entering the LAN server address; connection test.

Each stage is independently shippable and testable, in dependency order.

## Relevant domains (for /research)

- `resumable-upload` — FastAPI large-file chunked/resumable upload patterns
  (tus protocol vs a small custom protocol) paired with a Flutter client
  that can pause/resume across connectivity changes; also covers verifying
  `connectivity_plus`'s current maintenance status and API (the owner named
  the library, but the exact stream/API needs confirming, same as other
  libraries in this repo that turned out to need version pins).
- `background-jobs` — lightweight background job orchestration inside a
  FastAPI app with no external queue/broker (in-process + SQLite-persisted
  state), specifically for occasional long-running CPU-bound jobs on a
  single-user home server, including crash/restart recovery.
