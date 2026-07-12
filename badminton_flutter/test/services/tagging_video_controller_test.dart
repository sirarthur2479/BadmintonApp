import 'package:flutter_test/flutter_test.dart';
import 'package:badminton_flutter/services/tagging_video_controller.dart';

import '../fakes/fake_tagging_video_controller.dart';

void main() {
  group('stepTarget', () {
    const frame = Duration(microseconds: 16667); // 60 fps
    const total = Duration(seconds: 10);

    test('steps forward and back by n frames', () {
      const pos = Duration(seconds: 5);
      expect(
        stepTarget(pos, 1, frame, total),
        pos + const Duration(microseconds: 16667),
      );
      expect(
        stepTarget(pos, -3, frame, total),
        pos - const Duration(microseconds: 50001),
      );
    });

    test('clamps below zero', () {
      expect(stepTarget(Duration.zero, -1, frame, total), Duration.zero);
      expect(
        stepTarget(const Duration(milliseconds: 5), -1, frame, total),
        Duration.zero,
      );
    });

    test('clamps above duration', () {
      expect(stepTarget(total, 5, frame, total), total);
    });
  });

  group('FakeTaggingVideoController contract', () {
    test('position pushes reach listeners and stepFrames pauses', () async {
      final fake = FakeTaggingVideoController(
        videoDuration: const Duration(minutes: 10),
      );
      await fake.init('/videos/match.mp4');

      final seen = <Duration>[];
      fake.position.addListener(() => seen.add(fake.position.value));

      fake.pushPosition(const Duration(seconds: 3));
      fake.pushPosition(const Duration(seconds: 4));
      expect(seen, [const Duration(seconds: 3), const Duration(seconds: 4)]);

      await fake.play();
      expect(fake.isPlaying, isTrue);

      await fake.stepFrames(1);
      expect(fake.isPlaying, isFalse, reason: 'stepping always pauses first');
      expect(fake.seeks, isNotEmpty);
    });

    test('records seeks and speeds', () async {
      final fake = FakeTaggingVideoController(
        videoDuration: const Duration(minutes: 10),
      );
      await fake.init('/videos/match.mp4');

      await fake.seekTo(const Duration(seconds: 42));
      await fake.setSpeed(0.5);

      expect(fake.seeks, [const Duration(seconds: 42)]);
      expect(fake.speeds, [0.5]);
      expect(fake.position.value, const Duration(seconds: 42));
    });
  });
}
