# Match-log feature — per-match reflection log

- **Status:** done (TASK-035 → TASK-041, 2026-07-12)
- **Added:** 2026-07-12
- **Source:** `ideas/pool.md` #9 — feature originally built on the
  `A2-remote-signin-improve-log-feature` branch, recovered as a *description*
  from the stash diff during the rebase onto main. The code itself was not
  kept (and its duplicate backend / auth-service files were rejected), so this
  is a guided rebuild on top of the multi-player architecture, not a port.

## Problem

Match play is where training shows up, but the app can only record matches as
thin `Match` rows inside a `Tournament` (opponent / scores / isWin). There is
no place for the reflection that actually drives improvement: what the
gameplan was going in, how ready the player felt, what worked and broke down
move-by-move, and which video captures the match. Practice matches that
happen outside tournaments can't be logged at all.

## Target users

- The player (12-year-old regional junior): fills in pre-match gameplan and
  post-match reflection, revisits past match logs before playing the same
  opponent again.
- The parent/coach: reviews logs, adds context, and exports a log as Markdown
  to feed AI analysis (same consumption path as the #3 session export).

## Desired outcome

1. A standalone `MatchLog` record, **not** tied to a `tournamentId`, scoped
   by `playerId` like every other data type since the multi-player rework:
   - context: date, opponent, event/context label (practice, league,
     tournament round), result/scores;
   - pre-match: gameplan, readiness (small enum or 1–5 score);
   - post-match: performance notes (what worked / what broke down),
     key moments, video reference(s);
   - fields stay compatible with the existing camelCase `toMap()` ↔ SQLite ↔
     backend pass-through convention.
2. The Train tab becomes a two-sub-tab container (`TrainScreen`): **Sessions**
   (existing `SessionHistoryScreen` content) and **Match Logs** (new list of
   `MatchLogCard`s + FAB → `LogMatchScreen`). It replaces
   `SessionHistoryScreen` in `MainShell._tabs` without breaking web's
   login → player-select → shell routing.
3. Full parity with the session data path:
   - mobile: sqflite table via `DatabaseService` (schema bump v4 → v5; like
     `sessions`, no local `playerId` column — mobile is single-player
     offline and scoping happens server-side via the route path);
   - web: `DatabaseService.webApi` delegation to new `ApiService` methods;
   - backend: `match_logs` table + `/players/{player_id}/match-logs` routes
     in `badminton_backend` mirroring `routers/sessions.py`
     (list / upsert / batch / update / delete, `require_player` ownership
     dependency), with pytest coverage matching the sessions tests.
4. A match log can be exported to Markdown via the existing `ExportService`
   pattern so it can be pasted into an AI-analysis chat, mirroring the
   session export from #3.

## Constraints

- Backend additions must follow the TASK-021 stack: PyJWT + pwdlib[argon2]
  only; `python-jose`/`passlib` are banned (see `research/fastapi-auth.md`).
  No new auth code should be needed — reuse `require_player`.
- Provider must follow the `SessionProvider` pattern (load-once + `refresh()`,
  optimistic local list updates) and be registered in `main.dart`'s
  `MultiProvider`; `MainShell.initState` should load match logs alongside
  sessions/tournaments/profile.
- Mobile stays offline-first (no auth); web goes through the JWT'd API — the
  split lives entirely inside `DatabaseService`, as today.
- Existing `Tournament`/`Match` data is untouched; no migration of old
  `matches` rows into match logs.
- Video reference is a plain path/URL string field for now — it may later
  point at a BadmintonTrack analysis artifact (#6), but no upload/analysis
  coupling in this feature.

## Explicitly out of scope (split from the original branch)

- `youtube_player_widget.dart` (inline technique video playback) — unrelated
  to the match-log data model; belongs with the technique-library items in
  pool idea #7.
- The old branch's duplicate backend (`badminton-server/`) and duplicate
  `auth_service.dart`/`api_service.dart` — already rejected, not part of
  this idea.

## Open questions (non-blocking, defaults chosen)

- Readiness representation → default to a 1–5 score with a `StarRating`
  widget, consistent with `goalAchievementScore`.
- Result representation → keep it simple and consistent with `Match`:
  free-form scores string + explicit win/loss flag; no set-by-set model.
- Home-screen stats integration (win rate, matches this month) → not in the
  first cut; the Home tab is untouched.

## Implementation sketch

1. **Model:** `lib/models/match_log.dart` — `MatchLog` with
   `copyWith`/`toMap`/`fromMap` + round-trip unit tests (TASK-005 pattern).
2. **Local DB:** schema v5 in `database_service.dart` (`match_logs` table),
   CRUD methods with `kIsWeb → webApi` delegation.
3. **Backend:** `match_logs` table in `app/database.py`, `MatchLog` Pydantic
   model, `app/routers/match_logs.py` cloned from `sessions.py`, router
   registration in `main.py`, pytest suite mirroring the sessions tests.
4. **ApiService:** `getMatchLogs`/`insertMatchLog(s)`/`updateMatchLog`/
   `deleteMatchLog` against `/players/{id}/match-logs`.
5. **Provider:** `match_log_provider.dart` following `SessionProvider`;
   register in `main.dart`, load in `MainShell.initState`.
6. **UI:** `screens/train/train_screen.dart` (TabBar container),
   `screens/train/log_match_screen.dart` (create/edit form),
   `widgets/match_log_card.dart`; swap into `MainShell._tabs`; widget tests
   for the tab swap and form save path.
7. **Export:** extend `ExportService` with `matchLogToMarkdown` and surface
   it from the match-log detail/card menu.

## Relevant domains

None new. All required patterns are already in-repo and researched:
backend routes (`research/fastapi-auth.md`, TASK-023 pattern), Flutter data
layer (TASK-026 pattern), Markdown export (TASK-013 pattern). No `/research`
run needed.
