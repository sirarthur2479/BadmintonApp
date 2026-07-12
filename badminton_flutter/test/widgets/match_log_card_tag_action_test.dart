import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:badminton_flutter/models/match_log.dart';
import 'package:badminton_flutter/widgets/match_log_card.dart';

MatchLog _log({String? videoRef}) => MatchLog(
  id: 'log-1',
  date: DateTime(2026, 7, 12),
  opponent: 'Ken T.',
  isWin: true,
  videoRef: videoRef,
);

Future<void> _pump(
  WidgetTester tester, {
  required MatchLog log,
  VoidCallback? onTagPoints,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MatchLogCard(log: log, onTagPoints: onTagPoints),
      ),
    ),
  );
}

void main() {
  testWidgets('tag points action shows for a log with video', (tester) async {
    var tapped = 0;
    await _pump(
      tester,
      log: _log(videoRef: '/videos/match.mp4'),
      onTagPoints: () => tapped++,
    );

    await tester.tap(find.byTooltip('Tag points'));
    expect(tapped, 1);
  });

  testWidgets('tag points action hidden without videoRef', (tester) async {
    await _pump(tester, log: _log(), onTagPoints: () {});

    expect(find.byTooltip('Tag points'), findsNothing);
  });

  testWidgets('tag points action hidden when no callback is wired (web)', (
    tester,
  ) async {
    await _pump(tester, log: _log(videoRef: '/videos/match.mp4'));

    expect(find.byTooltip('Tag points'), findsNothing);
  });

  testWidgets('tapping the opponent name fires onOpponentTap', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatchLogCard(
            log: _log(),
            onOpponentTap: () => tapped++,
          ),
        ),
      ),
    );

    await tester.tap(find.textContaining('Ken T.'));
    expect(tapped, 1);
  });
}
