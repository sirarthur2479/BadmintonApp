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
