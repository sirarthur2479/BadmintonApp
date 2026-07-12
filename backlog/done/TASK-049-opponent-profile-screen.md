# TASK-049 - Opponent profile screen + navigation

**Use case:** [ideas/use-cases/match-point-analysis.md](../../ideas/use-cases/match-point-analysis.md)
**Research:** [research/flutter-video.md](../../research/flutter-video.md) (screen conventions n/a — UI task)
**Depends on:** TASK-045, TASK-048
**Effort:** M
**Risk:** low
**Status:** done

## Goal

Surface the profiling: an opponents list (from match logs) and a per-opponent
profile screen rendering the TASK-048 aggregates, reachable from the Match
Logs tab and from a match-log card's opponent name. Works with zero tagged
points (logs-only head-to-head, with "tag points to unlock" empty states) —
profiling never requires the video pipeline.

## Acceptance criteria

- `lib/screens/train/opponents_screen.dart`: list of `OpponentSummary`
  cards (name, W–L, matches, last played), sorted by last played desc;
  reachable from an "Opponents" app-bar action on the Match Logs tab.
- `lib/screens/train/opponent_profile_screen.dart`: takes the opponent key +
  display name; loads that opponent's logs and all point records (provider
  `allPoints()`), computes `OpponentStats.compute`, renders sections:
  head-to-head header (W–L, matches, points won %), serve vs receive card,
  rally-length bands, their winners by shot, unforced-error profiles,
  pressure points, ending zones. Sections with no data render the
  "Tag points from a match video to unlock" empty state instead of zeros.
- Tapping the opponent name on a `MatchLogCard` opens the profile screen.
- Match history section lists that opponent's logs (existing card widget,
  read-only tap-through to edit screen).
- Widget tests cover populated and empty-data renders with seeded ffi DB.
- `flutter test` green, analyzer clean.

## Test plan (`test/screens/opponents_screen_test.dart`, `test/screens/opponent_profile_screen_test.dart`, RED first)

- `opponents list groups match logs per opponent with win loss`
- `opponents list sorts by last played descending`
- `profile header shows head to head from logs alone`
- `profile stat sections render from tagged points`
- `profile shows unlock empty state with zero tagged points`
- `opponent name tap on a match log card opens the profile`
- `opponents action on match logs tab opens the list`

## Implementation plan

1. RED widget tests with seeded in-memory DB (two opponents, one with
   tagged points, one without).
2. `OpponentsScreen` (reuses `OpponentSummary`), app-bar action on
   `match_logs_tab.dart`.
3. `OpponentProfileScreen` (stat section widgets kept dumb; all math stays
   in TASK-048's module).
4. `MatchLogCard` opponent-name tap target.
5. GREEN per slice, full suite.
