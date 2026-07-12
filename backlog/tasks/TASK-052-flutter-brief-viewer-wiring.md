# TASK-052 - Flutter brief request wiring + viewer/export

**Use case:** [ideas/use-cases/match-point-analysis.md](../../ideas/use-cases/match-point-analysis.md)
**Research:** [research/local-llm.md](../../research/local-llm.md)
**Depends on:** TASK-049, TASK-050, TASK-051
**Effort:** M
**Risk:** medium
**Status:** todo

## Goal

Close the loop in the app: a "Tactical brief" action on the opponent profile
screen that sends the TASK-050 facts to the TASK-051 endpoint (web: the
normal `ApiClient`; mobile: the LAN analysis-server client, TASK-031
pattern), shows the returned Markdown in a viewer (analysis-report-screen
pattern: selectable text, share action), and degrades gracefully to the
metrics-only brief when no server/Ollama is reachable — profiling never
hard-requires the LLM.

## Acceptance criteria

- `ApiService`/`ApiClient` path gains
  `requestOpponentBrief(String opponent, List<String> facts)` →
  `POST /coach/opponent-brief`, returning the Markdown string; mobile uses
  the analysis-server client only when `AnalysisServerProvider.isReady`.
- Opponent profile screen gains a "Tactical brief" button:
  - server reachable → loading state → `OpponentBriefScreen` with the LLM
    Markdown (selectable, share/export via the existing export pattern);
  - no server configured / request fails → the metrics-only brief
    (TASK-050) opens instead, with an unobtrusive note ("AI narrative
    unavailable — showing metrics only"), no error dialog on the happy
    fallback path.
- The brief screen renders Markdown the same way the analysis report screen
  does (reuse that widget/approach — no new Markdown dependency unless it
  already exists there).
- All HTTP faked in tests (recording fake client); web/mobile split covered
  by the existing `webOverride`/provider seams.
- `flutter test` green, analyzer clean.

## Test plan (`test/screens/opponent_brief_test.dart` + api-service additions, RED first)

- `request opponent brief posts opponent and facts and returns markdown`
- `brief button shows llm markdown when the server responds`
- `brief button falls back to metrics-only brief when no server configured`
- `brief button falls back to metrics-only brief on request failure`
- `fallback brief carries the ai-unavailable note`
- `brief screen offers share export`

## Implementation plan

1. RED: api-service unit tests (fake HTTP) + screen widget tests (fake
   brief client seam injected through the profile screen).
2. Add the client method (both `ApiService` and the LAN path — share the
   implementation via `ApiClient` as uploads/settings do).
3. `OpponentBriefScreen` (reuse analysis-report rendering) + profile-screen
   button with the fallback ladder.
4. Export/share wiring.
5. GREEN per slice, full suite. Closes the use-case (phase 2 stays parked
   per the research gate; the owner-run TrackNetV3 pilot is the upgrade
   path).
