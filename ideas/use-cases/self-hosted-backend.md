# Use case: self-hosted-backend

**Status:** planned (TASK-021 → TASK-027)
**Created:** 2026-07-06
**Source:** `badminton_flutter/docs/self-hosting-plan.md` +
`self-hosting-setup.md` (complete spec, pool idea #5), reviewed against the
codebase as of TASK-013.

## Problem

The Flutter app is fully offline. Mobile persists to local SQLite, but the
**web build stores everything in in-memory arrays** — every browser refresh
erases all data, making the web version demo-only. There is no login, no
way for one family account to manage two players, and no home for the
BadmintonTrack-12 analysis service (pool #6) to attach to later. The owner
wants to self-host at home: no cloud cost, data stays on their machine.

## Target users

- The parent/coach (registers the account, manages players, runs the server)
- The player(s) (use the web app; a second child can be added later)
- Indirectly: pool idea #6, which will reuse this server + JWT auth for
  video upload/analysis.

## Desired outcome

The already-written plan, implemented:

1. **Backend API** (`FastAPI` + SQLite + JWT): `/api/v1/auth/register|login`,
   players CRUD, and per-player sessions/tournaments/matches endpoints —
   every data route verifies `players.accountId == JWT.sub`. Account →
   Players hierarchy (one login, many players; all data scoped to
   `playerId`). 30-day token expiry.
2. **Flutter web goes persistent**: login/register screens, player-select
   screen with an active-player switcher, `ApiService` with the JWT header,
   and `DatabaseService`'s `kIsWeb` branches delegating to the API instead
   of in-memory lists. **Mobile stays offline-first and untouched.**
3. **Deployable at home**: Docker Compose (backend + nginx serving the web
   build and proxying `/api/`), documented Cloudflare Tunnel exposure.
   Actual home-server deployment is an owner-run step from
   `self-hosting-setup.md`, not a repo deliverable.

Success = register → add 2 players → log sessions per player → switch player
→ correct data shown; second account cannot touch the first's data; browser
refresh keeps login + data; `docker compose down && up` keeps everything.

## Constraints

- **⚠ The plan's serialization notes are stale.** They predate Part A
  (TASK-007/008): `drills` is now a **JSON array string** (comma format is
  legacy-read-only), sessions carry `sessionGoal`, `goalAchievementScore`,
  `playerRemarks`, `coachRemarks`, `reflectionAnswersJson`, and `intensity`
  is nullable. The backend schema and payloads must match the **current**
  Flutter `toMap()/fromMap()` exactly (scores stay pipe-delimited, `isWin`
  0/1, client-generated UUIDs).
- Backend lives in the monorepo as a new top-level project
  (`badminton_backend/`, PROJECT_TYPE python-api, pytest) — the plan's
  `~/badminton/` layout is the *deployment* copy, not the source location.
  Deployment docs updated accordingly.
- The plan's pinned dependency versions are 2024-era; re-pin to current at
  implementation time, and verify the JWT/password-hash library choice is
  still the maintained one (see relevant domains).
- Privacy posture: data about minors stays on the owner's hardware; JWT
  secret via environment, never committed; no third-party analytics.
- Backend fully testable headless (`pytest` + FastAPI `TestClient`, temp
  SQLite per test). Flutter changes testable with the existing
  ffi/mock patterns (mock `ApiService`/HTTP; no live server in tests).
- Web photo upload is out of scope (mobile keeps `PhotoStore`; web sessions
  simply have no photos yet — matches today's behaviour).

## Open questions

None blocking — the plan resolves the big ones (account→players model,
JWT expiry, playerId-scoped URLs, mobile unchanged). Judgment calls for
/plan:
- Auth library choice (`python-jose` per the plan vs the currently
  maintained alternative) — decided by `research/fastapi-auth.md`.
- Whether the web build's `custom_tags` (TASK-008) also sync via API or
  stay device-local; simplest consistent answer: per-player endpoint,
  same pattern as sessions.

## Implementation sketch

Staged per the plan's implementation order, adjusted for the repo:

1. **Backend scaffold + auth** — `badminton_backend/` package, DB schema
   (matching current Flutter columns), register/login, JWT dependency,
   password hashing; pytest suite with TestClient.
2. **Backend players + data routes** — players CRUD with ownership checks;
   sessions/tournaments/matches routes incl. batch insert; the
   playerId-ownership test matrix (cannot read/mutate across accounts).
3. **Flutter auth + player select** — `AuthProvider` (token storage:
   localStorage/web, `flutter_secure_storage`/mobile), login/register
   screens, `PlayerProvider` + player-select screen + switcher, auth gate
   in `app.dart`.
4. **Flutter web data layer** — `ApiService`, `DatabaseService` web
   branches delegate to it, providers thread `activePlayerId`.
5. **Compose + deployment docs** — Dockerfile, docker-compose.yml, nginx
   conf, refresh `self-hosting-setup.md` (new paths, current serialization
   note, Cloudflare Tunnel unchanged).

## Relevant domains

- `fastapi-auth` — verify the 2026-current JWT + password-hashing stack for
  FastAPI (python-jose maintenance status, PyJWT, passlib/bcrypt vs argon2)
  and pin versions. Everything else (FastAPI/SQLite/Docker/nginx/Flutter
  http) is standard and fully specced in the plan doc — no further research.
