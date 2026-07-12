# Research: flutter-video

**Date:** 2026-07-12
**Triggering use-case:** [Match-point analysis](../ideas/use-cases/match-point-analysis.md) (Phase 1 — human-in-the-loop tagging from video)

## Need summary

The point-tagging screen in `badminton_flutter` must play back a LOCAL match
video (recorded on the same iPhone; 1080p60, 10+ minutes, 1–2 GB) with
reliable scrubbing, precise (non-keyframe) seek, small-step forward/back
(~frame or sub-second), playback-speed control, and a position stream accurate
enough to stamp `videoTimestampMs` on each of 40–80 tagged points. Primary
platform iOS; Android nice-to-have; web playback NOT required (tagging can be
mobile-only, like the existing upload features). Local files only — no
streaming/DRM/ads. Privacy: footage of a minor, so no packages that phone home
or require accounts. Must fit the repo's testing convention: widget tests with
injectable hand-driven fakes (TusUploader pattern), so the player controller
must be mockable without a real platform view. Current app deps (pubspec):
Flutter SDK `^3.11.1`, no video package yet.

## Candidates evaluated

Scoring: functionality fit 30% · maintenance 20% · community 20% ·
documentation 15% · licence 10% · dependency footprint 5%. Each axis 1–5.
Likes / versions / dates verified 2026-07-12 by fetching the pub.dev /
GitHub pages unless marked ~ (unverified).

| # | Name | What | Likes / stars | Last release | Licence | Weighted | Decision |
|---|------|------|---------------|--------------|---------|---------:|----------|
| 1 | [video_player](https://pub.dev/packages/video_player) | Official Flutter plugin: AVPlayer (iOS) / ExoPlayer (Android) behind one controller | 3.71k likes, 2.66M downloads | v2.12.0, 2026-07-11 | BSD-3-Clause | **4.70** | **adopt** |
| 2 | Native AVPlayer via platform channel | Build-your-own: direct AVFoundation (`AVPlayerItem.step(byCount:)`, zero-tolerance seek) | n/a (Apple framework) | n/a | n/a | **4.25** | skip (escalation path only) |
| 3 | [fvp](https://pub.dev/packages/fvp) | video_player backend swap via libmdk (FFmpeg): accurate seek + `fastSeekTo` + frame-step flags | 173 likes / 349★ | v0.37.3, ~2026-07-01 | BSD-3-Clause (plugin; libmdk binary is prebuilt/closed) | **3.90** | skip (documented fallback) |
| 4 | [chewie](https://pub.dev/packages/chewie) | Material/Cupertino playback controls on top of video_player | 2.35k likes | v1.14.1, ~2026-05 | MIT | **3.90** | skip (we build our own tagging controls) |
| 5 | [media_kit](https://github.com/media-kit/media-kit) | libmpv-based full player engine (FFI), own `Player` + `Video` widget | 900 likes / 1.8k★ | v1.2.6, ~2025-12 (7 months ago) | MIT | **3.80** | skip (engine-swap fallback) |
| 6 | [video_player_media_kit](https://pub.dev/packages/video_player_media_kit) | Adapter: video_player API backed by media_kit | 107 likes | v2.0.0, ~2025-12 | MIT | **3.15** | skip |
| 7 | [flick_video_player](https://pub.dev/packages/flick_video_player) | UI/architecture layer over video_player (GeekyAnts) | 598 likes | v0.9.0, ~2024-08 (23 months ago) | MIT | **2.85** | skip |
| 8 | [better_player_plus](https://pub.dev/packages/better_player_plus) | Community fork of archived better_player; streaming/DRM/PiP feature player | 167 likes | v1.3.4, ~2026-06 | Apache-2.0 | **2.65** | skip |
| 9 | [video_editor](https://pub.dev/packages/video_editor) | Trim/crop editor UI on video_player (thumbnail trim slider) | 600 likes | v3.0.0, ~2023 (3 years ago) | MIT | 2.55 | skip (copy trim-slider pattern) |
| 10 | [pod_player](https://pub.dev/packages/pod_player) | video_player wrapper aimed at YouTube/Vimeo streaming | 435 likes | v0.2.2, ~2024 (2 years ago) | MIT | 2.40 | skip |

Axis scores for the top 8 (fit/maint/community/docs/licence/deps):
video_player 4/5/5/5/5/5 · native AVPlayer 5/3/4/4/5/5 · fvp 5/4/3/3/4/3 ·
chewie 2/5/5/4/5/4 · media_kit 4/3/4/4/5/2 · video_player_media_kit
3/3/3/3/5/2 · flick_video_player 2/2/3/4/5/3 · better_player_plus 2/3/2/3/5/2.

## Per-candidate notes (top 8)

**video_player — adopt.** The official plugin clears every hard requirement,
and the two facts that usually disqualify it for precision work are both fixed:

- *Seek precision:* the changelog states "`VideoPlayerController.seekTo()` is
  now frame accurate on both platforms" (since v0.6.2) — on iOS this is
  AVPlayer's zero-tolerance seek (`toleranceBefore/After = kCMTimeZero`,
  Apple's documented sample-accurate mode), not keyframe snapping. For a local
  1080p60 H.264/HEVC file recorded on the same phone, exact seeks are fast:
  AVPlayer decodes from the nearest keyframe on-device with hardware decode,
  and iPhone camera recordings have frequent keyframes (~1s GOP ~).
- *Position granularity:* the position update interval was reduced from 500ms
  to **100ms in v2.9.4** — so `value.position` is comfortably accurate for
  point-level `videoTimestampMs` deep links (a rally is seconds long; 100ms
  slop is invisible). Constraint: **require `video_player: ^2.9.4`** (we'll
  take current ^2.12.0). Known caveat: flutter/flutter#116056 — the reported
  position and the displayed frame can differ within that granularity; for
  exact stamps, pause first, then read position (paused position is stable).
- *Frame-step:* there is **no native step API** — but because `seekTo` is
  frame-accurate, stepping is emulable: pause, then
  `seekTo(position ± n × (1000/60) ms)` (clamped). Sub-second steps (e.g.
  ±250ms / ±1s buttons) need nothing special. This is the one place the
  official plugin is "emulated rather than native"; if it ever feels laggy on
  device, escalation paths are #2 and #3 below.
- *Speed / large files:* `setPlaybackSpeed()` is built in; AVPlayer/ExoPlayer
  stream from disk, so 1–2 GB local files are a non-issue (no in-memory load).
- *Testability (the clincher):* video_player is architected around a federated
  `VideoPlayerPlatform` interface, and the officially recommended test pattern
  is to register a fake platform that pushes `VideoEvent`s (initialized,
  position, completed) through a `StreamController` — tests can drive
  position/duration with zero platform views. `VideoPlayerController` is also
  a plain `ValueNotifier<VideoPlayerValue>`. Either hook works with the repo's
  hand-driven-fake convention.
- BSD-3, flutter.dev verified publisher, released the day before this
  research, no telemetry, zero size cost beyond OS players already on device.

**Native AVPlayer via platform channel — skip (escalation only).** AVFoundation
gives everything natively: zero-tolerance `seek(to:)`, real frame stepping via
`AVPlayerItem.step(byCount:)`, `AVPlayerItem.currentTime()` at any precision.
But it means writing and maintaining our own iOS platform view + channel
protocol, losing Android for free, and re-solving everything video_player
already solved. Only justified if emulated frame-stepping through video_player
proves unusably slow on device — and even then, a narrower option is a tiny
method-channel *addition* (step-only) alongside video_player rather than a
full player. Documented, not planned.

**fvp — skip (documented fallback).** Genuinely impressive: one line
(`fvp.registerWith()`) swaps video_player's backend to libmdk while keeping
the exact same Dart API (so our wrapper/tests don't change), and the mdk
engine supports accurate seek by default plus `fastSeekTo()` (keyframe) and
true frame stepping (`seek(±n, SeekFlag.fromNow|frame)`), HDR, and lower
CPU/GPU load than libmpv players; ~10MB per arch. Actively released (v0.37.3,
11 days ago; BSD-3 plugin). Two reasons it's not the pick: single-maintainer
bus factor with a smaller community (349★/173 likes), and the libmdk core is
distributed as a **prebuilt closed-source binary** — weak fit for a
privacy-first app holding footage of a minor (no telemetry is *claimed* ~, but
it can't be audited). Because it is API-compatible with video_player, adopting
it later is a two-line change — the perfect fallback if AVPlayer/ExoPlayer
seek latency disappoints.

**chewie — skip.** Healthy (Flutter Community, 2.35k likes, recent release)
but it is a consumer-playback *controls skin* over video_player. The tagging
screen needs a bespoke scrubber + step buttons + tag flow, not
Material/Cupertino play controls; chewie adds nothing we'd keep. Its source is
a good reference for scrubber gesture handling.

**media_kit — skip (engine-swap fallback).** MIT, mpv underneath, exact seeks
(mpv hr-seek is precise for absolute seeks ~), a rich `Player.stream.position`
that updates far more often than 100ms, and frame-stepping is reachable via
the mpv `frame-step` command on the `NativePlayer` (not exposed as public
cross-platform API ~). But: last release ~7 months ago with 322 open issues
and a history of maintainer gaps; iOS is its least-mature platform; the
bundled libmpv/FFmpeg libs cost tens of MB on iOS (~, vs zero for AVPlayer);
and there is no official fake — testability means wrapping `Player` behind
our own interface (doable, but no better than video_player). Everything it
adds over video_player, we don't need for local files.

**video_player_media_kit — skip.** Neat adapter (video_player API, media_kit
engine) that would preserve our wrapper if we ever needed the mpv engine, but
it inherits media_kit's size/maturity costs while keeping video_player's API
limits (no frame-step surface). If we outgrow AVPlayer, fvp is the
lighter-footprint version of the same move.

**flick_video_player — skip.** Another UI layer over video_player; 23 months
without a release, and its value (prebuilt controls, wakelock, web keyboard)
is orthogonal to a tagging scrubber.

**better_player_plus — skip.** Community fork of the archived better_player
(original discontinued ~2024 ~). Its weight is in HLS/DASH, DRM, caching,
PiP, playlists — all explicitly out of scope for local-file tagging — and it
vendors its own forked native player code (bigger surface, unverified
uploader) without adding seek precision or frame-stepping.

**Also noted:** `video_editor` (skip; stale 3 years, but its thumbnail
trim-slider is the reference pattern if we later want a thumbnail strip on the
scrubber — it, too, just uses video_player underneath) and `pod_player`
(skip; YouTube/Vimeo-focused, 2 years stale).

## Recommendation

Concrete plan for the phase-1 tagging screen:

- **Adopt `video_player: ^2.12.0`** (floor `>=2.9.4` for the 100ms position
  interval). iOS 13+ requirement is already satisfied by the app. Play the
  local recording via `VideoPlayerController.file(File(videoRef))`.
- **Wrap it behind a repo-owned interface** — `TaggingVideoController`
  (pattern-match `TusUploader`): roughly
  `init(String path)`, `Duration get duration`, `Stream<Duration> positions`
  (or expose the `ValueNotifier`), `Future<void> seekTo(Duration)`,
  `Future<void> stepFrames(int n)`, `setSpeed(double)`, `play()/pause()`,
  `dispose()`. Production impl delegates to `VideoPlayerController`;
  `stepFrames` = pause + frame-accurate `seekTo(position + n × 16.67ms)`
  (frame duration derived from metadata where available, 60fps default).
- **Tests:** a hand-driven `FakeTaggingVideoController` (manual position
  pushes, scripted durations) drives all widget tests for `TagPointsScreen` —
  scrub, step, speed, and timestamp-capture flows run with no platform view,
  exactly like the upload tests. (If we ever want to test the real wrapper,
  video_player's official fake-`VideoPlayerPlatform` pattern covers that too.)
- **Timestamp capture:** tag actions pause first, then read
  `value.position.inMilliseconds` → `videoTimestampMs`. 100ms granularity is
  far inside the tolerance for a point-level deep link.
- **UI:** build the scrubber + step buttons + speed selector ourselves (small
  `Slider`-based widget over the interface); chewie/video_editor are pattern
  references only.
- **Fallback ladder (documented, not built):** (1) if step/seek latency on
  device is poor → `fvp.registerWith()` — same Dart API, real frame-step and
  fastSeek in the mdk backend, ~10MB/arch, closed-binary caveat; (2) if a
  full engine swap is ever needed → media_kit (MIT, mpv), accepting its iOS
  size and maintenance-cadence costs. The `TaggingVideoController` seam makes
  either a one-file change.
- **Privacy posture:** video_player is first-party, telemetry-free, and plays
  from the local file system only — nothing leaves the phone.

## Search log

Queries run (WebSearch/WebFetch, 2026-07-12):

1. `Flutter video_player seekTo precision iOS AVPlayer keyframe frame accurate seek toleranceBefore` — key finding: seekTo is frame-accurate on both platforms; surfaced flutter#72416 (users asking for the *opposite*: faster keyframe seek).
2. video_player changelog fetch — confirmed "frame accurate on both platforms" (v0.6.2) and position interval 500ms → **100ms in v2.9.4**; latest v2.12.0 published 2026-07-11.
3. `media_kit flutter accurate seek frame stepping mpv local video playback` — seek-accuracy improvements confirmed; also surfaced media-kit#471 (choppy scrub UX report).
4. pub.dev fetches: media_kit (900 likes, v1.2.6, 7 months old, MIT), fvp (173 likes, v0.37.3, 11 days, BSD-3), better_player_plus (167 likes, v1.3.4, 23 days, Apache-2.0), chewie (2.35k likes, v1.14.1), pod_player (435 likes, 2 years stale), flick_video_player (598 likes, 23 months stale), video_editor (600 likes, 3 years stale), video_player (3.71k likes, v2.12.0), video_player_media_kit (107 likes, v2.0.0).
5. `fvp flutter libmdk accurate seek SeekFlag frame step video_player backend` — confirmed mdk frame-step forward/backward via `seek(±n, SeekFlag.FromNow|Frame)` and keyframe SeekFlag.
6. GitHub fetches: media-kit/media-kit (1.8k★, 322 open issues, MIT), wang-bin/fvp (349★, BSD-3, `registerWith()` + `fastSeekTo()` extension).
7. `media_kit flutter package maintained 2025 2026 …` — active issues through 2026-06, but no release since v1.2.6 (~Dec 2025).
8. `video_player_avfoundation seekTo toleranceBefore zero accurate seek iOS` — Apple docs: zero tolerance = sample-accurate seek; direct source-file fetch was proxy-blocked (404), so the zero-tolerance implementation detail rests on the official changelog claim, marked accordingly.
9. `flutter video_player widget test fake VideoPlayerPlatform mock controller position testing` — flutter#131743: recommended pattern is mocking `VideoPlayerPlatform`; StreamController-driven fakes for position events.
10. `media_kit iOS app size increase …` — no authoritative number found; iOS libs size marked ~. `fvp flutter app size mdk-sdk …` — ~10MB per arch (from fvp docs), ~2MB with system ffmpeg.
11. `best Flutter video player package 2026 comparison …` — no additional serious candidates beyond the list above (Flutter Gems video category cross-checked).

Verification notes: GitHub API and raw.githubusercontent were proxy-gated this
session, so per-file source verification of video_player's iOS seek tolerance
was not possible — the frame-accuracy claim is sourced from the official
changelog instead. better_player (original) archive date, mpv hr-seek default,
iPhone GOP length, media_kit iOS binary size, and libmdk telemetry absence are
marked ~ (unverified).
