import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:badminton_flutter/models/match_log.dart';
import 'package:badminton_flutter/models/session.dart';
import 'package:badminton_flutter/providers/match_log_provider.dart';
import 'package:badminton_flutter/providers/point_record_provider.dart';
import 'package:badminton_flutter/providers/session_provider.dart';
import 'package:badminton_flutter/screens/train/opponent_profile_screen.dart';
import 'package:badminton_flutter/screens/train/opponents_screen.dart';
import 'package:badminton_flutter/screens/train/train_screen.dart';
import 'package:badminton_flutter/services/database_service.dart';

MatchLog _log(
  String id, {
  String opponent = 'Ken T.',
  bool isWin = true,
  DateTime? date,
}) => MatchLog(
  id: id,
  date: date ?? DateTime(2026, 7, 12),
  opponent: opponent,
  isWin: isWin,
);

Future<MatchLogProvider> _seed(
  WidgetTester tester,
  List<MatchLog> logs, {
  List<TrainingSession> sessions = const [],
}) async {
  await tester.runAsync(() async {
    await DatabaseService.resetForTests();
    await DatabaseService.insertMatchLogs(logs);
    for (final s in sessions) {
      await DatabaseService.insertSession(s);
    }
  });
  final provider = MatchLogProvider();
  await tester.runAsync(provider.loadMatchLogs);
  return provider;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbName = 'opponents_screen_test.db';
  });

  testWidgets('opponents list groups match logs per opponent with win loss', (
    tester,
  ) async {
    final provider = await _seed(tester, [
      _log('a', date: DateTime(2026, 6, 1)),
      _log('b', isWin: false, date: DateTime(2026, 7, 1)),
      _log('c', opponent: 'Mia W.', date: DateTime(2026, 5, 1)),
    ]);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: OpponentsScreen()),
      ),
    );

    expect(find.text('Ken T.'), findsOneWidget);
    expect(find.text('Mia W.'), findsOneWidget);
    expect(find.textContaining('1W – 1L'), findsOneWidget);
    expect(find.textContaining('1W – 0L'), findsOneWidget);
  });

  testWidgets('opponents list sorts by last played descending', (
    tester,
  ) async {
    final provider = await _seed(tester, [
      _log('a', opponent: 'Old Opponent', date: DateTime(2026, 1, 1)),
      _log('b', opponent: 'New Opponent', date: DateTime(2026, 7, 1)),
    ]);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: OpponentsScreen()),
      ),
    );

    final oldY = tester.getTopLeft(find.text('Old Opponent')).dy;
    final newY = tester.getTopLeft(find.text('New Opponent')).dy;
    expect(newY, lessThan(oldY));
  });

  testWidgets('opponents action on the match logs tab opens the list', (
    tester,
  ) async {
    final matchLogs = await _seed(tester, [_log('a')]);
    final sessions = SessionProvider();
    final points = PointRecordProvider();
    await tester.runAsync(sessions.loadSessions);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: sessions),
          ChangeNotifierProvider.value(value: matchLogs),
          ChangeNotifierProvider.value(value: points),
        ],
        child: const MaterialApp(home: TrainScreen()),
      ),
    );

    // The action lives on the Match Logs tab only.
    expect(find.byTooltip('Opponents'), findsNothing);
    await tester.tap(find.text('Match Logs'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Opponents'), findsOneWidget);

    await tester.tap(find.byTooltip('Opponents'));
    await tester.pumpAndSettle();

    expect(find.byType(OpponentsScreen), findsOneWidget);
    expect(find.text('Ken T.'), findsOneWidget);
  });

  testWidgets('tapping an opponent row opens the profile', (tester) async {
    final provider = await _seed(tester, [_log('a')]);
    final points = PointRecordProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: provider),
          ChangeNotifierProvider.value(value: points),
        ],
        child: const MaterialApp(home: OpponentsScreen()),
      ),
    );

    await tester.tap(find.text('Ken T.'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OpponentProfileScreen), findsOneWidget);
  });
}
