import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:badminton_flutter/models/match_log.dart';
import 'package:badminton_flutter/widgets/match_log_card.dart';
import 'package:badminton_flutter/widgets/star_rating.dart';

MatchLog log({bool isWin = true, int readiness = 4, String? videoRef}) =>
    MatchLog(
      id: 'log-1',
      date: DateTime(2026, 7, 12),
      opponent: 'Ken T.',
      eventContext: 'League round 3',
      scores: '21-15, 18-21, 21-19',
      isWin: isWin,
      readinessScore: readiness,
      videoRef: videoRef,
    );

Future<void> pumpCard(
  WidgetTester tester,
  MatchLog log, {
  VoidCallback? onDelete,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: MatchLogCard(log: log, onDelete: onDelete)),
    ),
  );
}

void main() {
  testWidgets('win chip shows WIN with the scores', (tester) async {
    await pumpCard(tester, log(isWin: true));

    expect(find.text('WIN'), findsOneWidget);
    expect(find.textContaining('21-15, 18-21, 21-19'), findsOneWidget);
  });

  testWidgets('loss renders a LOSS chip', (tester) async {
    await pumpCard(tester, log(isWin: false));

    expect(find.text('LOSS'), findsOneWidget);
    expect(find.text('WIN'), findsNothing);
  });

  testWidgets('readiness renders as stars', (tester) async {
    await pumpCard(tester, log(readiness: 2));

    final stars = tester.widget<StarRating>(find.byType(StarRating));
    expect(stars.value, 2);
  });

  testWidgets('delete icon fires onDelete', (tester) async {
    var deleted = false;
    await pumpCard(tester, log(), onDelete: () => deleted = true);

    await tester.tap(find.byIcon(Icons.delete_outline));

    expect(deleted, isTrue);
  });
}
