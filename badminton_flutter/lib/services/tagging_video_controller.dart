import 'package:flutter/foundation.dart';

/// The tagging screen's only view of video playback (pool #10 phase 1).
///
/// Repo-owned seam per research/flutter-video.md: production wraps the
/// official video_player plugin; tests drive a hand-driven fake; and if
/// on-device seek latency ever disappoints, fvp's registerWith() swaps the
/// backend without touching callers of this interface.
abstract class TaggingVideoController {
  /// Prepares the local file for playback. Must be called before anything
  /// else; [duration] is valid only after it completes.
  Future<void> init(String filePath);

  Duration get duration;

  /// Current playback position. Timestamp captures must pause first, then
  /// read this — the paused position is stable (research note).
  ValueListenable<Duration> get position;

  bool get isPlaying;

  Future<void> play();

  Future<void> pause();

  Future<void> seekTo(Duration target);

  /// Pause, then seek by [n] frames (negative steps back). Emulated via
  /// frame-accurate seekTo — video_player has no native step API.
  Future<void> stepFrames(int n);

  Future<void> setSpeed(double speed);

  void dispose();
}

/// Where a [frames]-step from [position] lands, clamped to the video.
Duration stepTarget(
  Duration position,
  int frames,
  Duration frameDuration,
  Duration total,
) {
  final target = position + frameDuration * frames;
  if (target < Duration.zero) return Duration.zero;
  if (target > total) return total;
  return target;
}
