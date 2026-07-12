import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import 'tagging_video_controller.dart';

/// Production [TaggingVideoController] over the official video_player
/// plugin (research/flutter-video.md): frame-accurate seekTo on iOS/Android
/// and 100ms position updates since 2.9.4. Frame-stepping is emulated —
/// pause, then an exact seek of n × frame duration (60fps default, matching
/// the iPhone recordings). If device latency ever disappoints, fvp's
/// registerWith() swaps the backend under this same class.
class VideoPlayerTaggingController implements TaggingVideoController {
  VideoPlayerTaggingController({
    this.frameDuration = const Duration(microseconds: 16667),
  });

  final Duration frameDuration;

  VideoPlayerController? _inner;
  final _position = ValueNotifier<Duration>(Duration.zero);

  void _onTick() {
    final value = _inner?.value;
    if (value != null && value.isInitialized) {
      _position.value = value.position;
    }
  }

  @override
  Future<void> init(String filePath) async {
    final inner = VideoPlayerController.file(File(filePath));
    _inner = inner;
    await inner.initialize();
    inner.addListener(_onTick);
  }

  @override
  Duration get duration => _inner?.value.duration ?? Duration.zero;

  @override
  ValueListenable<Duration> get position => _position;

  @override
  bool get isPlaying => _inner?.value.isPlaying ?? false;

  @override
  Future<void> play() async => _inner?.play();

  @override
  Future<void> pause() async => _inner?.pause();

  @override
  Future<void> seekTo(Duration target) async {
    await _inner?.seekTo(target);
    _onTick();
  }

  @override
  Future<void> stepFrames(int n) async {
    // Pause first: the paused position is the stable one to step from and
    // to stamp timestamps with (flutter#116056).
    await pause();
    await seekTo(stepTarget(_position.value, n, frameDuration, duration));
  }

  @override
  Future<void> setSpeed(double speed) async =>
      _inner?.setPlaybackSpeed(speed);

  /// The inner controller, for composing a VideoPlayer view in the screen.
  VideoPlayerController? get inner => _inner;

  @override
  void dispose() {
    _inner?.removeListener(_onTick);
    _inner?.dispose();
    _position.dispose();
  }
}
