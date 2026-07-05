import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:badminton_flutter/models/session.dart';
import 'package:badminton_flutter/providers/session_provider.dart';
import 'package:badminton_flutter/screens/export_screen.dart';
import 'package:badminton_flutter/screens/train/session_history_screen.dart';
import 'package:badminton_flutter/services/database_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbName = 'export_screen_test.db';
  });

  Future<SessionProvider> seed(WidgetTester tester,
      {List<TrainingSession> sessions = const []}) async {
    final provider = SessionProvider();
    await tester.runAsync(() async {
      await DatabaseService.resetForTests();
      await provider.loadSessions();
      for (final s in sessions) {
        await provider.addSession(s);
      }
    });
    return provider;
  }

  TrainingSession session(String id, int daysAgo) => TrainingSession(
        id: id,
        date: DateTime.now().subtract(Duration(days: daysAgo)),
        durationMinutes: 60,
        drills: const ['Smash'],
        sessionGoal: 'goal $id',
      );

  Future<void> pump(WidgetTester tester, SessionProvider provider) async {
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: const MaterialApp(home: ExportScreen()),
    ));
  }

  testWidgets('shows the session count for the default 30-day range',
      (tester) async {
    final provider = await seed(tester, sessions: [
      session('in-1', 2),
      session('in-2', 10),
      session('out-1', 60), // outside the default range
    ]);

    await pump(tester, provider);

    expect(find.textContaining('2 sessions in range'), findsOneWidget);
  });

  testWidgets('export button disabled when the range holds no sessions',
      (tester) async {
    final provider = await seed(tester); // empty

    await pump(tester, provider);

    expect(find.textContaining('0 sessions in range'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Export as Markdown'));
    expect(button.onPressed, isNull, reason: 'nothing to export');
  });

  testWidgets('export button enabled when sessions are in range',
      (tester) async {
    final provider = await seed(tester, sessions: [session('in-1', 1)]);

    await pump(tester, provider);

    final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Export as Markdown'));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('history screen app bar opens the export screen',
      (tester) async {
    final provider = await seed(tester, sessions: [session('in-1', 1)]);

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: const MaterialApp(home: SessionHistoryScreen()),
    ));

    final exportIcon = find.byIcon(Icons.ios_share);
    expect(exportIcon, findsOneWidget,
        reason: 'history app bar must expose the export entry point');

    await tester.tap(exportIcon);
    await tester.pumpAndSettle();
    expect(find.byType(ExportScreen), findsOneWidget);
  });
}
