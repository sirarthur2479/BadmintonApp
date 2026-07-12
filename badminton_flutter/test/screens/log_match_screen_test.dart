import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:badminton_flutter/models/match_log.dart';
import 'package:badminton_flutter/providers/match_log_provider.dart';
import 'package:badminton_flutter/screens/train/log_match_screen.dart';
import 'package:badminton_flutter/services/database_service.dart';

Future<MatchLogProvider> pumpForm(
  WidgetTester tester, {
  MatchLog? existing,
  Future<String?> Function()? videoPicker,
}) async {
  await tester.runAsync(() => DatabaseService.resetForTests());
  final provider = MatchLogProvider();
  await tester.runAsync(() => provider.loadMatchLogs());

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        home: LogMatchScreen(existing: existing, videoPicker: videoPicker),
      ),
    ),
  );
  return provider;
}

Future<void> enterField(WidgetTester tester, String key, String text) async {
  await tester.scrollUntilVisible(
    find.byKey(ValueKey(key)),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.enterText(find.byKey(ValueKey(key)), text);
}

Future<void> saveForm(WidgetTester tester, MatchLogProvider provider) async {
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('saveMatchButton')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  // scrollUntilVisible stops at partial visibility; nudge the list so the
  // button's center is actually inside the viewport.
  await tester.drag(find.byType(ListView), const Offset(0, -200));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('saveMatchButton')));
  await tester.pump();
  // The save path does real sqflite work; give it real time.
  await tester.runAsync(() async {
    for (var i = 0; i < 200 && provider.matchLogs.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });
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

    await enterField(tester, 'opponentField', 'Ken T.');
    await enterField(tester, 'eventContextField', 'League round 3');
    await enterField(tester, 'scoresField', '21-15, 21-17');
    await enterField(tester, 'gameplanField', 'Attack the backhand');
    await enterField(tester, 'performanceNotesField', 'Smash worked');
    await enterField(tester, 'keyMomentsField', 'Comeback in game 2');
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
    expect(
      find.byType(LogMatchScreen),
      findsOneWidget,
      reason: 'screen must not pop on a blocked save',
    );
  });

  testWidgets('edit mode pre-fills and updates with the same id', (
    tester,
  ) async {
    final existing = MatchLog(
      id: 'edit-me',
      date: DateTime(2026, 7, 5),
      opponent: 'Ken T.',
      eventContext: 'Practice',
      scores: '21-10, 21-12',
      isWin: false,
      gameplan: 'Serve variation',
      readinessScore: 2,
      performanceNotes: 'Slow start',
      keyMoments: 'None',
      videoRef: '/videos/practice.mp4',
    );
    final provider = await pumpForm(tester, existing: existing);
    await tester.runAsync(() => provider.addMatchLog(existing));

    // Pre-filled fields and edit-mode chrome.
    expect(find.text('Edit Match'), findsOneWidget);
    expect(find.text('Ken T.'), findsOneWidget);
    expect(find.text('Practice'), findsOneWidget);
    expect(find.text('21-10, 21-12'), findsOneWidget);
    expect(find.text('Serve variation'), findsOneWidget);

    await enterField(tester, 'performanceNotesField', 'Found rhythm late');
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update Match'));
    await tester.runAsync(() async {
      for (
        var i = 0;
        i < 200 &&
            provider.matchLogs.single.performanceNotes != 'Found rhythm late';
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });

    final saved = provider.matchLogs.single;
    expect(saved.id, 'edit-me', reason: 'update must keep the id');
    expect(saved.performanceNotes, 'Found rhythm late');
    expect(saved.opponent, 'Ken T.');
    expect(saved.isWin, isFalse);
    expect(saved.readinessScore, 2);
    expect(saved.videoRef, '/videos/practice.mp4');
  });

  testWidgets('win/loss toggle and readiness stars land in the saved log', (
    tester,
  ) async {
    final provider = await pumpForm(tester);

    await enterField(tester, 'opponentField', 'Mia W.');
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

  group('video picker', () {
    testWidgets('choose-video button fills the field from the picker', (
      tester,
    ) async {
      await pumpForm(
        tester,
        videoPicker: () async => '/videos/league-r3.mp4',
      );

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('pickVideoButton')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('pickVideoButton')));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('videoRefField')),
      );
      expect(field.controller!.text, '/videos/league-r3.mp4');
    });

    testWidgets('cancelling the picker leaves the field untouched', (
      tester,
    ) async {
      await pumpForm(tester, videoPicker: () async => null);

      await enterField(tester, 'videoRefField', '/existing.mp4');
      await tester.tap(find.byKey(const ValueKey('pickVideoButton')));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('videoRefField')),
      );
      expect(field.controller!.text, '/existing.mp4');
    });

    testWidgets('without a seam the button opens the source sheet', (
      tester,
    ) async {
      await pumpForm(tester);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('pickVideoButton')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('pickVideoButton')));
      await tester.pumpAndSettle();

      expect(find.text('Photo library'), findsOneWidget);
      expect(find.text('Browse files'), findsOneWidget);
    });
  });
}
