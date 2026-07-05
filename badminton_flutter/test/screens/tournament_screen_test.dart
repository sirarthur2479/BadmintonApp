import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:badminton_flutter/models/tournament.dart';
import 'package:badminton_flutter/providers/tournament_provider.dart';
import 'package:badminton_flutter/screens/profile/tournament_screen.dart';
import 'package:badminton_flutter/services/database_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbName = 'tournament_screen_test.db';
  });

  Future<TournamentProvider> seed(WidgetTester tester) async {
    final provider = TournamentProvider();
    await tester.runAsync(() async {
      await DatabaseService.resetForTests();
      final t = Tournament(
        id: const Uuid().v4(),
        name: 'Regional U13',
        date: DateTime(2026, 6, 1),
        location: 'Auckland',
        format: 'Knockout',
      );
      await provider.addTournament(t);
      await provider.addMatch(TournamentMatch(
        id: const Uuid().v4(),
        tournamentId: t.id,
        opponent: 'A. Rival',
        scores: const ['21-15'],
        isWin: true,
      ));
    });
    return provider;
  }

  Future<void> pumpScreen(
      WidgetTester tester, TournamentProvider provider) async {
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: const MaterialApp(home: TournamentScreen()),
    ));
    // Expand the tournament tile.
    await tester.tap(find.text('Regional U13'));
    await tester.pumpAndSettle();
  }

  testWidgets('tournament delete shows confirm dialog and deletes on confirm',
      (tester) async {
    final provider = await seed(tester);
    await pumpScreen(tester, provider);

    await tester.tap(find.text('Delete tournament'));
    await tester.pumpAndSettle();
    expect(find.text('Delete tournament?'), findsOneWidget,
        reason: 'destructive action must confirm first');

    await tester.runAsync(() async {
      await tester.tap(find.text('Delete'));
      await tester.pump();
      // Real-async window so the dialog pop resolves and the DB call
      // (running on the ffi isolate) can complete.
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();

    expect(provider.tournaments, isEmpty);
  });

  testWidgets('match delete confirms and keeps the match on cancel',
      (tester) async {
    final provider = await seed(tester);
    await pumpScreen(tester, provider);

    // The match row's trailing icon — scope to the ListTile so the
    // "Delete tournament" footer button's icon can't be matched.
    final matchDeleteIcon = find.descendant(
      of: find.widgetWithText(ListTile, 'vs A. Rival'),
      matching: find.byIcon(Icons.delete_outline),
    );
    await tester.runAsync(() async {
      await tester.tap(matchDeleteIcon);
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text('Delete match?'), findsOneWidget,
        reason: 'match delete must confirm before firing');

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(provider.tournaments.first.matches, hasLength(1),
        reason: 'cancel must keep the match');
  });
}
