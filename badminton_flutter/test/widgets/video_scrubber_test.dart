import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:badminton_flutter/widgets/video_scrubber.dart';

import '../fakes/fake_tagging_video_controller.dart';

Future<FakeTaggingVideoController> _pump(WidgetTester tester) async {
  final fake = FakeTaggingVideoController(
    videoDuration: const Duration(minutes: 10),
  );
  await fake.init('/videos/match.mp4');
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: VideoScrubber(controller: fake))),
  );
  return fake;
}

void main() {
  testWidgets('slider reflects controller position pushes', (tester) async {
    final fake = await _pump(tester);

    fake.pushPosition(const Duration(minutes: 5));
    await tester.pump();

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, closeTo(0.5, 0.001), reason: '5 of 10 minutes');
  });

  testWidgets('dragging the slider seeks the controller', (tester) async {
    final fake = await _pump(tester);

    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(0.25);
    await tester.pump();

    expect(fake.seeks, [
      const Duration(minutes: 2, seconds: 30),
    ], reason: 'quarter of 10 minutes');
  });

  testWidgets('play/pause button toggles and reflects state', (tester) async {
    final fake = await _pump(tester);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    await tester.tap(find.byTooltip('Play'));
    await tester.pump();

    expect(fake.isPlaying, isTrue);
    expect(find.byIcon(Icons.pause), findsOneWidget);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();

    expect(fake.isPlaying, isFalse);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('frame-step buttons step plus and minus one frame', (
    tester,
  ) async {
    final fake = await _pump(tester);
    fake.pushPosition(const Duration(seconds: 5));
    await tester.pump();

    await tester.tap(find.byTooltip('Forward 1 frame'));
    await tester.tap(find.byTooltip('Back 1 frame'));
    await tester.pump();

    expect(fake.seeks, hasLength(2));
    expect(
      fake.seeks.first,
      const Duration(seconds: 5) + fake.frameDuration,
    );
    expect(fake.isPlaying, isFalse, reason: 'stepping pauses');
  });

  testWidgets('second-step buttons seek ±1s clamped at zero', (tester) async {
    final fake = await _pump(tester);

    await tester.tap(find.byTooltip('Back 1 second'));
    await tester.pump();
    expect(fake.seeks.last, Duration.zero, reason: 'clamped at start');

    fake.pushPosition(const Duration(seconds: 30));
    await tester.pump();
    await tester.tap(find.byTooltip('Forward 1 second'));
    await tester.pump();
    expect(fake.seeks.last, const Duration(seconds: 31));
  });

  testWidgets('speed selector calls setSpeed with the chosen rate', (
    tester,
  ) async {
    final fake = await _pump(tester);

    await tester.tap(find.byTooltip('Playback speed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('0.5×'));
    await tester.pumpAndSettle();

    expect(fake.speeds, [0.5]);
  });
}
