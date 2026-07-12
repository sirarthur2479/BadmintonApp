import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:badminton_flutter/models/match_log.dart';
import 'package:badminton_flutter/providers/match_log_provider.dart';
import 'package:badminton_flutter/screens/train/log_match_screen.dart';
import 'package:badminton_flutter/services/database_service.dart';
import 'package:badminton_flutter/widgets/star_rating.dart';

Future<MatchLogProvider> pumpForm(
  WidgetTester tester, {
  MatchLog? existing,
}) async {
  await tester.runAsync(() => DatabaseService.resetForTests());
  final provider = MatchLogProvider();
  await tester.runAsync(() => provider.loadMatchLogs());

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(home: LogMatchScreen(existing: existing)),
    ),
  );
  return provider;
}

Future<void> saveForm(WidgetTester tester, MatchLogProvider provider) async {
  await tester.ensureVisible(find.byKey(const ValueKey('saveMatchButton')));
  await tester.tap(find.byKey(const ValueKey('saveMatchButton')));
  // The save path does real sqflite work.
  await tester.runAsync(() => Future<void>.delayed(
        const Duration(milliseconds: 50),
      ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbName = 'log_match_screen_test.db';
  });

  testWidgets('saving a filled form adds a match log to the provider', (
    tester,
  ) async {
    final provider = await pumpForm(tester);

    await tester.enterText(
      find.byKey(const ValueKey('opponentField')),
      'Ken T.',
    );
    await tester.enterText(
      find.byKey(const ValueKey('eventContextField')),
      'League round 3',
    );
    await tester.enterText(
      find.byKey(const ValueKey('scoresField')),
      '21-15, 21-17',
    );
    await tester.enterText(
      find.byKey(const ValueKey('gameplanField')),
      'Attack the backhand',
    );
    await tester.enterText(
      find.byKey(const ValueKey('performanceNotesField')),
      'Smash worked',
    );
    await tester.enterText(
      find.byKey(const ValueKey('keyMomentsField')),
      'Comeback in game 2',
    );
    await saveForm(tester, provider);

    final saved = provider.matchLogs.single;
    expect(saved.id, isNotEmpty);
    expect(saved.opponent, 'Ken T.');
    expect(saved.eventContext, 'League round 3');
    expect(saved.scores, '21-15, 21-17');
    expect(saved.gameplan, 'Attack the backhand');
    expect(saved.performanceNotes, 'Smash worked');
    expect(saved.keyMoments, 'Comeback in game 2');
    expect(saved.isWin, isTrue, reason: 'result defaults to win');
    expect(saved.readinessScore, 3, reason: 'readiness defaults to 3 stars');
  });

  testWidgets('opponent is required - empty blocks the save', (tester) async {
    final provider = await pumpForm(tester);

    await saveForm(tester, provider);

    expect(provider.matchLogs, isEmpty);
    expect(find.byType(LogMatchScreen), findsOneWidget,
        reason: 'screen must not pop on a blocked save');
  });

  testWidgets('win/loss toggle and readiness stars land in the saved log', (
    tester,
  ) async {
    final provider = await pumpForm(tester);

    await tester.enterText(
      find.byKey(const ValueKey('opponentField')),
      'Mia W.',
    );
    await tester.tap(find.text('Loss'));
    await tester.pump();
    // Readiness stars: tap the 5th star of the readiness rating.
    final stars = find.byKey(const ValueKey('readinessStars'));
    await tester.tap(
      find.descendant(of: stars, matching: find.byIcon(Icons.star_border)).last,
    );
    await tester.pump();
    await saveForm(tester, provider);

    final saved = provider.matchLogs.single;
    expect(saved.isWin, isFalse);
    expect(saved.readinessScore, 5);
  });
}
