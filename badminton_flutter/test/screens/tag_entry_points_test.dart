import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:badminton_flutter/models/match_log.dart';
import 'package:badminton_flutter/providers/match_log_provider.dart';
import 'package:badminton_flutter/screens/train/log_match_screen.dart';
import 'package:badminton_flutter/screens/train/match_logs_tab.dart';
import 'package:badminton_flutter/services/database_service.dart';

MatchLog _log({String? videoRef}) => MatchLog(
  id: 'log-1',
  date: DateTime(2026, 7, 12),
  opponent: 'Ken T.',
  isWin: true,
  videoRef: videoRef,
);

Future<void> _pumpTab(
  WidgetTester tester, {
  required MatchLog log,
  bool? webOverride,
}) async {
  await tester.runAsync(() async {
    await DatabaseService.resetForTests();
    await DatabaseService.insertMatchLog(log);
  });
  final provider = MatchLogProvider();
  await tester.runAsync(provider.loadMatchLogs);

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        home: Scaffold(body: MatchLogsTab(webOverride: webOverride)),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbName = 'tag_entry_points_test.db';
  });

  testWidgets('match logs tab offers tag points for video logs off web', (
    tester,
  ) async {
    await _pumpTab(tester, log: _log(videoRef: '/videos/match.mp4'));

    expect(find.byTooltip('Tag points'), findsOneWidget);
  });

  testWidgets('match logs tab hides tag points on web', (tester) async {
    await _pumpTab(
      tester,
      log: _log(videoRef: '/videos/match.mp4'),
      webOverride: true,
    );

    expect(find.byTooltip('Tag points'), findsNothing);
  });

  testWidgets('match logs tab hides tag points without video', (tester) async {
    await _pumpTab(tester, log: _log());

    expect(find.byTooltip('Tag points'), findsNothing);
  });

  testWidgets('edit screen app bar offers tag points for video logs', (
    tester,
  ) async {
    await tester.runAsync(() => DatabaseService.resetForTests());
    final provider = MatchLogProvider();
    await tester.runAsync(provider.loadMatchLogs);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: LogMatchScreen(existing: _log(videoRef: '/videos/m.mp4')),
        ),
      ),
    );
    expect(find.byTooltip('Tag points'), findsOneWidget);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: LogMatchScreen(
            existing: _log(videoRef: '/videos/m.mp4'),
            webOverride: true,
          ),
        ),
      ),
    );
    expect(find.byTooltip('Tag points'), findsNothing);
  });
}
