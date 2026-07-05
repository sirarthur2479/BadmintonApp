import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:badminton_flutter/data/sample_sessions_seed.dart';
import 'package:badminton_flutter/models/reflection_data.dart';
import 'package:badminton_flutter/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbName = 'seed_gate_test.db';
  });

  setUp(() async {
    await DatabaseService.resetForTests();
  });

  test('sample sessions exercise the goal/reflection fields', () {
    final samples = buildSampleSessions();

    final withGoals = samples.where((s) => s.sessionGoal.isNotEmpty);
    expect(withGoals.length, greaterThanOrEqualTo(3),
        reason: 'a demo install must show off the goal UI');
    expect(withGoals.map((s) => s.goalAchievementScore).toSet().length,
        greaterThan(1),
        reason: 'scores should vary so the trend chart is not flat');

    final withAnswers = samples.where((s) =>
        decodeReflectionAnswers(s.reflectionAnswersJson).isNotEmpty);
    expect(withAnswers, isNotEmpty,
        reason: 'at least one sample carries reflection answers');
    expect(
        withAnswers.expand(
            (s) => decodeReflectionAnswers(s.reflectionAnswersJson)).every(
          (a) => kReflectionQuestions.contains(a.questionKey),
        ),
        isTrue,
        reason: 'sample answers must use the canonical question keys');

    expect(samples.every((s) => s.intensity != null), isTrue,
        reason: 'seeded rows model legacy data and keep their intensity');
  });

  test('seeds when flag unset and db empty', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final seeded = await seedSampleDataIfNeeded(prefs);

    expect(seeded, isTrue);
    expect(await DatabaseService.hasAnySessions(), isTrue);
  });

  test('does not seed when flag already set, even if db is empty', () async {
    // The user has deleted the demo data: flag set, DB empty.
    SharedPreferences.setMockInitialValues({kSampleDataSeededKey: true});
    final prefs = await SharedPreferences.getInstance();

    final seeded = await seedSampleDataIfNeeded(prefs);

    expect(seeded, isFalse);
    expect(await DatabaseService.hasAnySessions(), isFalse,
        reason: 'deleted demo data must stay deleted across restarts');
  });

  test('sets flag after seeding', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await seedSampleDataIfNeeded(prefs);

    expect(prefs.getBool(kSampleDataSeededKey), isTrue);
  });
}
