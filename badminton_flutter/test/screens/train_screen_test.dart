import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:badminton_flutter/models/match_log.dart';
import 'package:badminton_flutter/models/session.dart';
import 'package:badminton_flutter/providers/match_log_provider.dart';
import 'package:badminton_flutter/providers/session_provider.dart';
import 'package:badminton_flutter/screens/train/train_screen.dart';
import 'package:badminton_flutter/services/database_service.dart';
import 'package:badminton_flutter/widgets/match_log_card.dart';
import 'package:badminton_flutter/widgets/session_card.dart';

MatchLog log({
  String? id,
  DateTime? date,
  bool isWin = true,
  String opponent = 'Ken T.',
}) => MatchLog(
  id: id ?? 'log-1',
  date: date ?? DateTime(2026, 7, 12),
  opponent: opponent,
  isWin: isWin,
);

Future<(SessionProvider, MatchLogProvider)> pumpTrain(
  WidgetTester tester, {
  List<TrainingSession> sessions = const [],
  List<MatchLog> logs = const [],
}) async {
  await tester.runAsync(() async {
    await DatabaseService.resetForTests();
    for (final s in sessions) {
      await DatabaseService.insertSession(s);
    }
    await DatabaseService.insertMatchLogs(logs);
  });
  final sessionProvider = SessionProvider();
  final matchLogProvider = MatchLogProvider();
  await tester.runAsync(() async {
    await sessionProvider.loadSessions();
    await matchLogProvider.loadMatchLogs();
  });

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: sessionProvider),
        ChangeNotifierProvider.value(value: matchLogProvider),
      ],
      child: const MaterialApp(home: TrainScreen()),
    ),
  );
  return (sessionProvider, matchLogProvider);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbName = 'train_screen_test.db';
  });

  testWidgets('Train tab shows Sessions and Match Logs tabs', (tester) async {
    await pumpTrain(tester);

    expect(find.text('Train'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Sessions'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Match Logs'), findsOneWidget);
  });

  testWidgets('Match Logs tab shows empty state when provider has no logs', (
    tester,
  ) async {
    await pumpTrain(tester);

    await tester.tap(find.widgetWithText(Tab, 'Match Logs'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No match logs yet'), findsOneWidget);
    expect(find.byType(MatchLogCard), findsNothing);
  });

  testWidgets('Match Logs tab lists a card per log, newest first', (
    tester,
  ) async {
    await pumpTrain(
      tester,
      logs: [
        log(id: 'older', date: DateTime(2026, 7, 1), opponent: 'Mia W.'),
        log(id: 'newer', date: DateTime(2026, 7, 10), opponent: 'Sam L.'),
      ],
    );

    await tester.tap(find.widgetWithText(Tab, 'Match Logs'));
    await tester.pumpAndSettle();

    expect(find.byType(MatchLogCard), findsNWidgets(2));
    final samY = tester.getTopLeft(find.textContaining('Sam L.')).dy;
    final miaY = tester.getTopLeft(find.textContaining('Mia W.')).dy;
    expect(samY, lessThan(miaY), reason: 'newest log renders first');
  });

  testWidgets('Match Logs tab FAB opens the match flow, not sessions', (
    tester,
  ) async {
    await pumpTrain(tester);

    await tester.tap(find.widgetWithText(Tab, 'Match Logs'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Log Match'), findsOneWidget);
  });

  testWidgets('delete flows through the confirm dialog', (tester) async {
    final (_, matchLogs) = await pumpTrain(tester, logs: [log(id: 'doomed')]);

    await tester.tap(find.widgetWithText(Tab, 'Match Logs'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    // Cancel keeps the log.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(matchLogs.matchLogs, hasLength(1));

    // Confirm deletes it.
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.runAsync(() async {
      for (var i = 0; i < 500 && matchLogs.matchLogs.isNotEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();

    expect(matchLogs.matchLogs, isEmpty);
    expect(find.byType(MatchLogCard), findsNothing);
  });

  testWidgets('Sessions tab still lists sessions', (tester) async {
    await pumpTrain(
      tester,
      sessions: [
        TrainingSession(
          id: 's1',
          date: DateTime(2026, 7, 2),
          durationMinutes: 60,
          drills: const ['Footwork'],
          sessionGoal: 'Sharper net kills',
        ),
      ],
    );

    expect(find.byType(SessionCard), findsOneWidget);
  });
}
