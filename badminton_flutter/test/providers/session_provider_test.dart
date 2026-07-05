import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:badminton_flutter/models/session.dart';
import 'package:badminton_flutter/providers/session_provider.dart';
import 'package:badminton_flutter/services/database_service.dart';

TrainingSession _session(String note, {int day = 1}) => TrainingSession(
      id: const Uuid().v4(),
      date: DateTime(2026, 7, day),
      durationMinutes: 60,
      drills: const ['Footwork'],
      intensity: 3,
      notes: note,
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbName = 'session_provider_test.db';
  });

  setUp(() async {
    await DatabaseService.resetForTests();
  });

  test('refresh() picks up rows inserted behind the provider\'s back',
      () async {
    final provider = SessionProvider();
    await provider.loadSessions();
    expect(provider.sessions, isEmpty);

    // Insert directly at the DB layer — the provider doesn't know.
    await DatabaseService.insertSession(_session('inserted externally'));

    await provider.refresh();
    expect(provider.sessions, hasLength(1),
        reason: 'refresh must reload from the DB even after initial load');
  });

  test('loadSessions() is still a one-shot guard', () async {
    final provider = SessionProvider();
    await provider.loadSessions();

    await DatabaseService.insertSession(_session('inserted externally'));

    await provider.loadSessions();
    expect(provider.sessions, isEmpty,
        reason: 'loadSessions stays guarded; only refresh() reloads');
  });

  group('sessionsPerWeek', () {
    // Friday, so the current week starts Monday 2026-07-06.
    final today = DateTime(2026, 7, 10);
    final currentWeekStart = DateTime(2026, 7, 6);
    final previousWeekStart = DateTime(2026, 6, 29);

    test('counts a session that falls exactly on the week-start boundary',
        () async {
      final provider = SessionProvider();
      await provider.loadSessions();
      await DatabaseService.insertSession(
          _session('on boundary', day: currentWeekStart.day));
      await provider.refresh();

      final buckets = provider.sessionsPerWeek(weeks: 2, now: today);

      expect(buckets[currentWeekStart], 1);
    });

    test('returns 0 for a week with no sessions', () async {
      final provider = SessionProvider();
      await provider.loadSessions();

      final buckets = provider.sessionsPerWeek(weeks: 2, now: today);

      expect(buckets[previousWeekStart], 0);
      expect(buckets[currentWeekStart], 0);
    });

    test('excludes sessions outside the requested window', () async {
      final provider = SessionProvider();
      await provider.loadSessions();
      // 3 weeks before the current week start — outside a 2-week window.
      await DatabaseService.insertSession(TrainingSession(
        id: const Uuid().v4(),
        date: currentWeekStart.subtract(const Duration(days: 21)),
        durationMinutes: 60,
        drills: const ['Footwork'],
        intensity: 3,
      ));
      await provider.refresh();

      final buckets = provider.sessionsPerWeek(weeks: 2, now: today);

      expect(buckets.values.every((count) => count == 0), isTrue,
          reason: 'session 3 weeks back must not appear in a 2-week window');
    });
  });

  group('avgIntensityPerWeek', () {
    final today = DateTime(2026, 7, 10);
    final currentWeekStart = DateTime(2026, 7, 6);

    test('averages multiple sessions in the same week', () async {
      final provider = SessionProvider();
      await provider.loadSessions();
      await DatabaseService.insertSession(TrainingSession(
        id: const Uuid().v4(),
        date: currentWeekStart,
        durationMinutes: 60,
        drills: const ['Footwork'],
        intensity: 2,
      ));
      await DatabaseService.insertSession(TrainingSession(
        id: const Uuid().v4(),
        date: currentWeekStart.add(const Duration(days: 1)),
        durationMinutes: 60,
        drills: const ['Smash'],
        intensity: 4,
      ));
      await provider.refresh();

      final buckets = provider.avgIntensityPerWeek(weeks: 1, now: today);

      expect(buckets[currentWeekStart], 3.0);
    });

    test('returns 0.0 for an empty week', () async {
      final provider = SessionProvider();
      await provider.loadSessions();

      final buckets = provider.avgIntensityPerWeek(weeks: 1, now: today);

      expect(buckets[currentWeekStart], 0.0);
    });
  });
}
