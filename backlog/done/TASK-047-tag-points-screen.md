# TASK-047 - TagPointsScreen (phase-1 human-in-the-loop tagging)

**Use case:** [ideas/use-cases/match-point-analysis.md](../../ideas/use-cases/match-point-analysis.md)
**Research:** [research/flutter-video.md](../../research/flutter-video.md)
**Depends on:** TASK-045, TASK-046
**Effort:** M
**Risk:** medium
**Status:** done

## Goal

The tagging surface: from a match log that has a `videoRef`, open a screen
with the video (scrubber on top) and a fast tap flow underneath — winner →
ending type → optional ending shot → optional zone/side → save — with
server, score, and game derived (TASK-045) and `videoTimestampMs` captured
pause-then-read (TASK-046). Tagging 40–80 points must be a handful of taps
each; partial tagging is always saveable. Mobile-only, like uploads
(`webOverride` seam).

## Acceptance criteria

- `lib/screens/train/tag_points_screen.dart`, constructor takes the
  `MatchLog` and an injectable `TaggingVideoController` (defaults to the
  production impl).
- On first open with no existing points: a game-1 first-server prompt
  (two chips: us / opponent). With existing points: resumes — header shows
  derived game + running score and tagged-point count.
- Tag flow per point: big "We won" / "They won" buttons; `endingType`
  choice chips (winner / forced error / unforced error); optional
  `endingShot` chips (TASK-042 vocabulary); optional 6-zone grid +
  side toggle; Save appends via `PointRecordProvider.addPoint` with
  derived `server`/`playerScore`/`opponentScore`/`game`/`indexInGame` and
  `videoTimestampMs` from the paused position; the form resets for the
  next point. Undo removes the last point (provider `undoLast`).
- Save is disabled until winner + ending type are chosen; shot/zone stay
  optional (nullable in the record).
- Game rollover: when `isGameOver` fires the header announces the game and
  subsequent points land in the next game automatically.
- Entry point: a "Tag points" action on `MatchLogCard` (and the match-log
  edit screen app bar) shown only when `videoRef != null` and not on web
  (`webOverride` test seam, upload-feature pattern).
- All widget tests run with `FakeTaggingVideoController` + ffi DB; no
  platform video init. `flutter test` green, analyzer clean.

## Test plan (`test/screens/tag_points_screen_test.dart` + a match-log card addition, RED first)

- `first open asks who serves first in game 1`
- `tagging a point saves derived server score and game`
- `video timestamp is captured from the paused position`
- `save disabled until winner and ending type chosen`
- `optional shot and zone are saved when picked and null when skipped`
- `undo removes the last tagged point and rewinds the derived score`
- `reopening with existing points resumes at the derived score`
- `game rolls over after 21 with two clear`
- `tag points action hidden without videoRef`
- `tag points action hidden on web`

## Implementation plan

1. RED: screen widget tests drive the full flow through the fake controller
   and a seeded in-memory DB (match log fixture with `videoRef`).
2. Build the screen: `VideoScrubber` (TASK-046) + a `_PointForm` stateful
   section; derivation calls from TASK-045; provider wiring.
3. Card/app-bar entry actions with the `webOverride` seam.
4. GREEN per slice, full suite.
