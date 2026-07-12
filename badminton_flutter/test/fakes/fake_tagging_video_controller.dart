import 'package:flutter/foundation.dart';
import 'package:badminton_flutter/services/tagging_video_controller.dart';

/// Hand-driven fake (TusUploader-fake pattern): tests push positions and
/// script the duration; every interaction is recorded. No platform views.
class FakeTaggingVideoController implements TaggingVideoController {
  FakeTaggingVideoController({
    this.videoDuration = const Duration(minutes: 10),
    this.frameDuration = const Duration(microseconds: 16667),
  });

  final Duration videoDuration;
  final Duration frameDuration;

  final _position = ValueNotifier<Duration>(Duration.zero);
  bool _playing = false;

  String? initedPath;
  final seeks = <Duration>[];
  final speeds = <double>[];
  final playPauseLog = <String>[];

  /// Tests drive playback by pushing positions.
  void pushPosition(Duration position) {
    _position.value = position;
  }

  @override
  Future<void> init(String filePath) async {
    initedPath = filePath;
  }

  @override
  Duration get duration => videoDuration;

  @override
  ValueListenable<Duration> get position => _position;

  @override
  bool get isPlaying => _playing;

  @override
  Future<void> play() async {
    _playing = true;
    playPauseLog.add('play');
  }

  @override
  Future<void> pause() async {
    _playing = false;
    playPauseLog.add('pause');
  }

  @override
  Future<void> seekTo(Duration target) async {
    seeks.add(target);
    _position.value = target;
  }

  @override
  Future<void> stepFrames(int n) async {
    await pause();
    await seekTo(
      stepTarget(_position.value, n, frameDuration, videoDuration),
    );
  }

  @override
  Future<void> setSpeed(double speed) async {
    speeds.add(speed);
  }

  @override
  void dispose() {
    _position.dispose();
  }
}
