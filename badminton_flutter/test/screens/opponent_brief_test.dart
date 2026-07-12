import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:badminton_flutter/models/match_log.dart';
import 'package:badminton_flutter/providers/match_log_provider.dart';
import 'package:badminton_flutter/providers/point_record_provider.dart';
import 'package:badminton_flutter/screens/train/opponent_brief_screen.dart';
import 'package:badminton_flutter/screens/train/opponent_profile_screen.dart';
import 'package:badminton_flutter/services/database_service.dart';

MatchLog _log(String id) => MatchLog(
  id: id,
  date: DateTime(2026, 7, 12),
  opponent: 'Ken T.',
  isWin: true,
);

Future<void> _pumpProfile(
  WidgetTester tester, {
  Future<String> Function(String opponent, List<String> facts)? briefRequester,
}) async {
  await tester.runAsync(() async {
    await DatabaseService.resetForTests();
    await DatabaseService.insertMatchLog(_log('a'));
  });
  final matchLogs = MatchLogProvider();
  final points = PointRecordProvider();
  await tester.runAsync(matchLogs.loadMatchLogs);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: matchLogs),
        ChangeNotifierProvider.value(value: points),
      ],
      child: MaterialApp(
        home: OpponentProfileScreen(
          opponentKey: 'ken t.',
          displayName: 'Ken T.',
          briefRequester: briefRequester,
        ),
      ),
    ),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapBrief(WidgetTester tester) async {
  await tester.tap(find.text('Tactical brief'));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbName = 'opponent_brief_test.db';
  });

  testWidgets('brief button shows LLM markdown when the request succeeds', (
    tester,
  ) async {
    final seen = <String>[];
    await _pumpProfile(
      tester,
      briefRequester: (opponent, facts) async {
        seen.add(opponent);
        seen.addAll(facts);
        return '# Tactical brief — Ken T.\n\nServe low to the backhand.';
      },
    );

    await _tapBrief(tester);

    expect(find.byType(OpponentBriefScreen), findsOneWidget);
    expect(
      find.textContaining('Serve low to the backhand.'),
      findsOneWidget,
    );
    expect(find.textContaining('AI narrative unavailable'), findsNothing);
    expect(seen.first, 'Ken T.');
    expect(
      seen.any((s) => s.startsWith('Head-to-head vs Ken T.')),
      isTrue,
      reason: 'the deterministic facts are the request payload',
    );
  });

  testWidgets('falls back to the metrics-only brief on request failure', (
    tester,
  ) async {
    await _pumpProfile(
      tester,
      briefRequester: (opponent, facts) async =>
          throw StateError('server down'),
    );

    await _tapBrief(tester);

    expect(find.byType(OpponentBriefScreen), findsOneWidget);
    expect(
      find.textContaining('no AI narrative was generated'),
      findsOneWidget,
      reason: 'the body is the deterministic metrics-only brief',
    );
    expect(
      find.textContaining('AI narrative unavailable'),
      findsOneWidget,
      reason: 'unobtrusive note, no error dialog',
    );
  });

  testWidgets('falls back to metrics-only when no requester is available', (
    tester,
  ) async {
    // Production default off-web with no analysis server in scope.
    await _pumpProfile(tester, briefRequester: null);

    await _tapBrief(tester);

    expect(find.byType(OpponentBriefScreen), findsOneWidget);
    expect(find.textContaining('AI narrative unavailable'), findsOneWidget);
  });

  testWidgets('brief screen offers share export', (tester) async {
    await _pumpProfile(
      tester,
      briefRequester: (opponent, facts) async => '# Brief',
    );

    await _tapBrief(tester);

    expect(find.byTooltip('Share'), findsOneWidget);
  });
}
