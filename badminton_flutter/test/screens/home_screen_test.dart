import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:badminton_flutter/models/session.dart';
import 'package:badminton_flutter/providers/session_provider.dart';
import 'package:badminton_flutter/screens/home/home_screen.dart';
import 'package:badminton_flutter/services/database_service.dart';
import 'package:badminton_flutter/widgets/goal_achievement_chart.dart';
import 'package:badminton_flutter/widgets/star_rating.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbName = 'home_screen_test.db';
  });

  Future<SessionProvider> seed(WidgetTester tester,
      {TrainingSession? session}) async {
    final provider = SessionProvider();
    await tester.runAsync(() async {
      await DatabaseService.resetForTests();
      await provider.loadSessions();
      if (session != null) await provider.addSession(session);
    });
    return provider;
  }

  Future<void> pumpHome(WidgetTester tester, SessionProvider provider) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: const MaterialApp(home: HomeScreen()),
    ));
  }

  testWidgets('last-session card shows goal text and stars, not intensity',
      (tester) async {
    final provider = await seed(
      tester,
      session: TrainingSession(
        id: 'home-1',
        date: DateTime.now(),
        durationMinutes: 60,
        drills: const ['Smash'],
        sessionGoal: 'Sharper smashes',
        goalAchievementScore: 4,
      ),
    );

    await pumpHome(tester, provider);

    expect(find.text('Sharper smashes'), findsOneWidget);
    expect(find.byType(StarRating), findsWidgets);
    expect(find.textContaining('Intensity null'), findsNothing,
        reason: 'null intensity must never leak into the UI');
  });

  testWidgets('shows a Goal Achievement Trend section with the chart',
      (tester) async {
    final provider = await seed(
      tester,
      session: TrainingSession(
        id: 'home-2',
        date: DateTime.now(),
        durationMinutes: 60,
        drills: const ['Clear'],
        sessionGoal: 'goal',
        goalAchievementScore: 3,
      ),
    );

    await pumpHome(tester, provider);

    expect(find.text('Goal achievement trend', skipOffstage: false),
        findsOneWidget);
    expect(find.byType(GoalAchievementChart, skipOffstage: false),
        findsOneWidget);
  });

  testWidgets('legacy last session still shows its intensity', (tester) async {
    final provider = await seed(
      tester,
      session: TrainingSession(
        id: 'home-3',
        date: DateTime.now(),
        durationMinutes: 45,
        drills: const ['Footwork'],
        intensity: 3,
      ),
    );

    await pumpHome(tester, provider);

    expect(find.textContaining('Intensity 3/5'), findsOneWidget);
  });
}
