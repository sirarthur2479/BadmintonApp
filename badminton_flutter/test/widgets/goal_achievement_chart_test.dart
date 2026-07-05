import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:badminton_flutter/models/session.dart';
import 'package:badminton_flutter/providers/session_provider.dart';
import 'package:badminton_flutter/services/database_service.dart';
import 'package:badminton_flutter/widgets/goal_achievement_chart.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbName = 'goal_chart_test.db';
  });

  testWidgets('renders one bar group per week from provider data', (
    tester,
  ) async {
    final provider = SessionProvider();
    await tester.runAsync(() async {
      await DatabaseService.resetForTests();
      await provider.loadSessions();
      await provider.addSession(
        TrainingSession(
          id: 'chart-1',
          date: DateTime.now(),
          durationMinutes: 60,
          drills: const ['Smash'],
          sessionGoal: 'goal',
          goalAchievementScore: 5,
        ),
      );
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: Scaffold(body: GoalAchievementChart())),
      ),
    );

    final chart = tester.widget<BarChart>(find.byType(BarChart));
    expect(
      chart.data.barGroups,
      hasLength(8),
      reason: 'default window is 8 weeks',
    );
    expect(chart.data.maxY, 5, reason: 'goal achievement is a 1–5 scale');
  });
}
