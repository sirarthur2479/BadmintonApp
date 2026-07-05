import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:badminton_flutter/models/session.dart';
import 'package:badminton_flutter/providers/session_provider.dart';
import 'package:badminton_flutter/screens/train/log_session_screen.dart';
import 'package:badminton_flutter/services/database_service.dart';

final _existing = TrainingSession(
  id: 'edit-me',
  date: DateTime(2026, 7, 3),
  durationMinutes: 90,
  drills: const ['Footwork', 'Shadow Drill'], // second one is NOT built-in
  intensity: 4,
  notes: 'existing notes',
);

Widget _app(SessionProvider provider, {TrainingSession? session}) =>
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(home: LogSessionScreen(session: session)),
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbName = 'log_session_screen_test.db';
  });

  setUp(() async {
    await DatabaseService.resetForTests();
  });

  testWidgets('create mode keeps Log Session title and Save Session button',
      (tester) async {
    final provider = SessionProvider();
    await provider.loadSessions();

    await tester.pumpWidget(_app(provider));

    expect(find.text('Log Session'), findsOneWidget);
    expect(find.text('Save Session'), findsOneWidget);
    expect(find.text('Update Session'), findsNothing);
  });

  testWidgets('edit mode pre-fills date, duration, drills, and notes',
      (tester) async {
    final provider = SessionProvider();
    await provider.loadSessions();
    await provider.addSession(_existing);

    await tester.pumpWidget(_app(provider, session: _existing));

    expect(find.text('Fri, 3 Jul 2026'), findsOneWidget);
    expect(find.text('90 min', skipOffstage: false), findsWidgets);
    expect(find.text('existing notes'), findsOneWidget);

    final footworkChip =
        tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Footwork'));
    expect(footworkChip.selected, isTrue);
  });

  testWidgets('edit mode shows Edit Session title and Update Session button',
      (tester) async {
    final provider = SessionProvider();
    await provider.loadSessions();

    await tester.pumpWidget(_app(provider, session: _existing));

    expect(find.text('Edit Session'), findsOneWidget);
    expect(find.text('Update Session'), findsOneWidget);
    expect(find.text('Save Session'), findsNothing);
  });

  testWidgets('edit mode pre-selects a drill that is not in kDrillTypes',
      (tester) async {
    final provider = SessionProvider();
    await provider.loadSessions();

    await tester.pumpWidget(_app(provider, session: _existing));

    final shadowChip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Shadow Drill'));
    expect(shadowChip.selected, isTrue,
        reason: 'legacy/custom drills must not be dropped in edit mode');
  });

  testWidgets('updating a session keeps its id and does not add a new one',
      (tester) async {
    final provider = SessionProvider();
    await provider.loadSessions();
    await provider.addSession(_existing);

    await tester.pumpWidget(_app(provider, session: _existing));
    await tester.enterText(
        find.widgetWithText(TextField, 'existing notes'), 'edited notes');
    await tester.tap(find.text('Update Session'));
    await tester.pumpAndSettle();

    expect(provider.sessions, hasLength(1),
        reason: 'update must not duplicate the session');
    expect(provider.sessions.single.id, 'edit-me');
    expect(provider.sessions.single.notes, 'edited notes');
  });
}
