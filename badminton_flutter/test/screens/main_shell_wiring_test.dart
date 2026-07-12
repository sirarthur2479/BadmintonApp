import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:badminton_flutter/app.dart';
import 'package:badminton_flutter/models/match_log.dart';
import 'package:badminton_flutter/providers/match_log_provider.dart';
import 'package:badminton_flutter/providers/profile_provider.dart';
import 'package:badminton_flutter/providers/session_provider.dart';
import 'package:badminton_flutter/providers/tournament_provider.dart';
import 'package:badminton_flutter/services/database_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbName = 'main_shell_wiring_test.db';
  });

  setUp(() async {
    await DatabaseService.resetForTests();
  });

  testWidgets('MainShell loads match logs on startup', (tester) async {
    await tester.runAsync(
      () => DatabaseService.insertMatchLog(
        MatchLog(
          id: 'seeded-log',
          date: DateTime(2026, 7, 12),
          opponent: 'Ken T.',
          isWin: true,
        ),
      ),
    );
    final matchLogs = MatchLogProvider();
    // .value providers everywhere: the test owns their lifetime, so loads
    // that complete during teardown can't hit a disposed notifier.
    final sessions = SessionProvider();
    final tournaments = TournamentProvider();
    final profile = ProfileProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: sessions),
          ChangeNotifierProvider.value(value: tournaments),
          ChangeNotifierProvider.value(value: profile),
          ChangeNotifierProvider.value(value: matchLogs),
        ],
        child: const MaterialApp(home: MainShell()),
      ),
    );
    // Let initState's post-frame loads (real sqflite async) run to
    // completion.
    await tester.runAsync(() async {
      for (var i = 0; i < 50 && matchLogs.matchLogs.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();

    expect(
      matchLogs.matchLogs.map((l) => l.id),
      ['seeded-log'],
      reason: 'MainShell.initState must trigger loadMatchLogs()',
    );
  });
}
