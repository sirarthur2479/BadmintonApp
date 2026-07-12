# TASK-046 - TaggingVideoController seam + scrubber widget

**Use case:** [ideas/use-cases/match-point-analysis.md](../../ideas/use-cases/match-point-analysis.md)
**Research:** [research/flutter-video.md](../../research/flutter-video.md)
**Depends on:** -
**Effort:** M
**Risk:** medium
**Status:** done

## Goal

The video seam per the research doc: adopt `video_player: ^2.12.0` behind a
repo-owned `TaggingVideoController` interface (the `TusUploader` pattern) so
every widget test drives playback with a hand-driven fake and the production
backend can later swap to fvp without touching callers. Plus the bespoke
scrubber widget (slider + step buttons + speed) the tagging screen composes.

## Acceptance criteria

- `pubspec.yaml` gains `video_player: ^2.12.0` (floor comment: >=2.9.4 for
  the 100 ms position interval).
- `lib/services/tagging_video_controller.dart` defines the abstract
  interface: `Future<void> init(String filePath)`, `Duration get duration`,
  `ValueListenable<Duration> get position`, `bool get isPlaying`,
  `Future<void> play()`, `Future<void> pause()`,
  `Future<void> seekTo(Duration)`, `Future<void> stepFrames(int n)`
  (pause + frame-accurate seek of n × frame duration, 60 fps default,
  clamped to [0, duration]), `Future<void> setSpeed(double)`,
  `void dispose()`.
- `VideoPlayerTaggingController` implements it over
  `VideoPlayerController.file`; timestamp reads follow the research rule:
  step/tag paths pause first, then read position.
- `test/fakes/fake_tagging_video_controller.dart`: hand-driven fake with
  scriptable duration, manual position pushes, and call recording
  (`seeks`, `speeds`, `playPauseLog`) — no platform channels.
- `lib/widgets/video_scrubber.dart`: renders a `Slider` bound to
  position/duration, play/pause toggle, ±1 frame and ±1 s step buttons,
  and a speed selector (0.25× / 0.5× / 1×); all interactions go through the
  interface only.
- Scrubber widget tests run headless with the fake (no `video_player`
  platform init anywhere in tests).
- `flutter test` green, analyzer clean.

## Test plan (`test/widgets/video_scrubber_test.dart`, RED first)

- `slider position reflects controller position pushes`
- `dragging the slider seeks the controller`
- `play/pause button toggles and reflects state`
- `step buttons call stepFrames with plus and minus one`
- `second-step buttons seek plus and minus one second clamped at zero`
- `speed selector calls setSpeed with the chosen rate`
- `unit: stepFrames clamps below zero and above duration` (on the fake-driven
  production controller logic if extracted pure, else fake contract test)

## Implementation plan

1. RED: fake + scrubber tests first (fake is a test asset, written in RED).
2. Add the dependency; write the interface file.
3. Write `VideoPlayerTaggingController` (thin; the frame-duration math and
   clamping extracted as a pure `Duration stepTarget(Duration pos, int n,
   Duration frame, Duration total)` helper so it is unit-testable without
   platform code).
4. Write `VideoScrubber` against the interface.
5. GREEN, full suite. Manual on-device latency check is deferred to the
   owner (fallback ladder documented in the research doc).
