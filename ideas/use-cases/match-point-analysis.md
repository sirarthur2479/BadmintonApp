# Match-point analysis & opponent profiling

- **Status:** planned (TASK-042 → TASK-052)
- **Added:** 2026-07-12
- **Source:** `ideas/pool.md` #10 — owner prompt ("the centrepiece: stage 0
  record schema, phase 1 human-in-the-loop, phase 2 shuttle tracking (gated on
  a /research pass)"), scoped in the 2026-07-12 intake Q&A:
  tagging happens **from video afterwards**, records are **point-level but
  shot-ready**, output is **in-app stats + local-LLM tactical report**.

## Problem

Match logs (#9) capture subjective reflection — gameplan, readiness, notes —
but nothing captures the *objective* point-by-point story of a match. When the
player meets the same opponent again, there is no data to answer: how do their
points actually end? Do they win on smashes or on our unforced errors? Do they
fold in long rallies? Does our serve hold up under pressure? The
BadmintonTrack-12 coach narrative covers footwork and biomechanics in
training, not match tactics. Match footage already exists (recorded on the
phone, and since #6 uploaded to the home server), but nobody mines it.

## Target users

- The player (12-year-old regional junior): reviews an opponent's profile
  before a rematch; sees their own error/finishing patterns evolve.
- The parent/coach: tags points while re-watching match video (the
  human-in-the-loop), reads the tactical brief, uses it to set the next
  gameplan and pick drills.

## Desired outcome

Three stages, in the owner's own framing:

### Stage 0 — point record schema (the contract)

1. A `PointRecord` model attached to a `MatchLog` (`matchLogId` FK), one row
   per rally, **point-level but shot-ready**:
   - position: `game` (1–3), `indexInGame`;
   - `server` (`player` | `opponent`) — derivable (rally winner serves next;
     only each game's first server is a free choice) so the tagging UI
     auto-fills it, but stored so every record is self-contained;
   - `winner` (`player` | `opponent`) and running score after the point
     (auto-computed at tag time, editable);
   - how it ended: `endingType` (`winner` | `forcedError` | `unforcedError`),
     `endingShot` (serve/clear/drop/smash/net/drive/lift/push/block/other,
     nullable), `endingZone` (coarse 6-zone grid: front/mid/rear ×
     left/right, plus which side of the net, nullable);
   - `videoTimestampMs` (nullable) — deep link into the match video;
   - `shots`: a **reserved** JSON list of per-shot entries
     ({shotType, side, zone, timestampMs}), empty in phase 1, so phase 2
     auto-tracking can fill full rally sequences **without a schema
     migration**;
   - camelCase `toMap()`/`fromMap()` per repo convention, SQLite table on
     mobile, `point_records` table + player-scoped routes in
     `badminton_backend` (nested under match-logs), web parity via
     `ApiService` — the same three-surface contract as every data type since
     the multi-player rework.
2. The schema is the load-bearing contract: phase 1 (human tags) and phase 2
   (shuttle tracking) both emit it, and profiling consumes only it — the same
   pattern as the footwork telemetry contract (TASK-016).

### Phase 1 — human-in-the-loop tagging from video

3. A point-tagging screen in `badminton_flutter`, reachable from a match log
   that has a `videoRef`: video playback with scrub / seek / small-step
   controls and a fast tap-to-tag flow (winner → ending type → ending shot →
   zone; server and score auto-derived; timestamp captured from the player
   position). Tagging a full match (~40–80 points) must be comfortable in
   ≤ 15 minutes — tag burden per point is a handful of taps.
4. Records work offline on mobile (sqflite) and sync-parity on web (API),
   exactly like sessions/match logs. Partial tagging is fine — profiling
   works with whatever points exist.

### Opponent profiling (consumes stage 0, regardless of phase)

5. Deterministic per-opponent aggregates, computed in-app from match logs +
   point records grouped by opponent name (exact, case-insensitive):
   head-to-head record, points won %, serve-point vs receive-point win rate,
   rally-length distribution and win rate by band (short ≤ 4, medium 5–9,
   long 10+), opponent finishing-shot breakdown (what they hit winners with),
   both sides' unforced-error profile, pressure-point record (18+ scores),
   ending-zone breakdown. Pure functions, unit-tested (streak-utils
   pattern), surfaced on an opponent profile screen reachable from match
   logs.
6. A local-LLM tactical brief in the BadmintonTrack-12 coach style: the
   deterministic aggregates are pre-worded into facts (`build_summary`
   pattern — the LLM can never invent numbers), then a guarded local Ollama
   chat turns them into an age-appropriate gameplan ("serve low to the
   backhand", "extend rallies past 8 shots") with 2–3 drill suggestions.
   Generated on the home server (reusing the #6 LAN analysis-server path and
   badminton_track's guarded Ollama module), delivered as Markdown attached
   to the opponent profile and exportable like session/match-log exports.

### Phase 2 — shuttle tracking (gated on a /research pass)

7. **Gated:** automatic point extraction in `badminton_track` — detect rally
   boundaries, rally length, ending shot and landing zone from match footage
   (shuttle detection/tracking, e.g. TrackNet lineage) — filling the same
   `PointRecord`s (and their reserved `shots` lists) that phase 1 tags by
   hand. This phase is planned **only if** `research/shuttle-tracking.md`
   concludes it is feasible on the owner's constraints (1080p60 iPhone
   footage, Apple Silicon, fully local). If the verdict is negative or
   marginal, phase 2 stays parked and phase 1 remains the data path — the
   feature is still complete without it.

## Constraints

- **Privacy first:** footage of a minor. Video never leaves the phone/LAN
  (reuse #6's WiFi-only + LAN-only ingest rules); the LLM brief is local
  Ollama only (`-cloud` tags refused, TASK-020 pattern); no cloud CV/AI.
- Backend additions follow the TASK-021 stack: PyJWT + pwdlib[argon2],
  `require_player` ownership, non-leaking 404s; `python-jose`/`passlib`
  banned (`research/fastapi-auth.md`).
- Mobile stays offline-first: tagging and deterministic profiling must work
  with no server. Only the LLM brief may require the LAN server (it already
  requires Ollama), and it degrades gracefully to metrics-only, as the coach
  report does.
- The point schema must be identical across Dart model, SQLite, backend
  table, and (phase 2) Python emitter — one contract, no divergence.
- Existing `MatchLog` rows are untouched; points are additive. No migration
  of `Tournament`/`matches` rows.
- Video playback is local-file only (the recording on the device);
  no streaming from the server, no re-download.

## Open questions (non-blocking, defaults chosen)

- Zone granularity → default 6 zones per half (front/mid/rear × left/right);
  finer grids only if phase 2 lands and makes them free.
- Opponent identity → exact case-insensitive name match; no fuzzy merging.
  A rename/merge tool is out of scope.
- Brief trigger → generated on demand from the opponent profile screen (not
  auto after each match).
- First server of game 1 → asked once at tag start (games 2/3 carry over per
  rules: previous game's winner serves).

## Implementation sketch

1. **Stage 0 contract:** `lib/models/point_record.dart` (+ round-trip
   tests), sqflite schema bump with `point_records` table + CRUD,
   backend `point_records` table + nested
   `/players/{id}/match-logs/{log_id}/points` routes (sessions-router
   pattern), `ApiService` methods, `kIsWeb` delegation.
2. **Provider:** `PointRecordProvider` (per-match-log load, batch save
   during tagging, `SessionProvider` conventions).
3. **Tagging (phase 1):** video scrubber widget (package per
   `research/flutter-video.md`), `TagPointsScreen` with the tap flow +
   server/score derivation (pure, unit-tested), entry point on
   `MatchLogCard`/detail for logs with `videoRef`.
4. **Profiling:** pure `OpponentStats` aggregation module + tests;
   `OpponentProfileScreen` (head-to-head header, stat sections, brief
   button/viewer); entry from match-log card and opponent name.
5. **LLM brief:** deterministic facts builder (Dart or server-side Python —
   decide at /plan), backend brief endpoint reusing the jobs pattern +
   badminton_track's guarded Ollama chat; Markdown render + export.
6. **Phase 2 (only if research verdict is go):** shuttle-tracking module in
   `badminton_track` emitting `PointRecord`-shaped JSON, review/import flow
   marking auto-derived records for human confirmation.

## Relevant domains

- **shuttle-tracking** — `research/shuttle-tracking.md` (2026-07-12).
  **Gate verdict: MARGINAL → phase 2 is parked.** Shuttle detection / rally
  segmentation / rally length are feasible (TrackNetV3 pretrained weights or
  a YOLO11n fine-tune, offline MPS job); ending-shot type and per-shot lists
  are not — they stay human. Upgrade path: a half-day pilot running
  pretrained TrackNetV3 on 2–3 real rallies (needs the owner's footage, so
  it is a future owner-run spike, not a task in this plan).
- **flutter-video** — `research/flutter-video.md` (2026-07-12). Adopt the
  official `video_player` (frame-accurate iOS `seekTo`, 100 ms position
  stream since 2.9.4) behind a repo-owned tagging-controller seam with a
  hand-driven fake; `fvp` documented as a same-API backend fallback.
- local-llm — `research/local-llm.md` (2026-07-05, fresh) → reuse.
- cv-tracking — `research/cv-tracking.md` (2026-07-05, fresh) → reuse for
  phase-2 context.
- fastapi-auth / backend patterns — `research/fastapi-auth.md` (fresh) →
  reuse.
