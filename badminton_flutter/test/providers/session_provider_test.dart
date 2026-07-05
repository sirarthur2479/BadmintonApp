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

  test(
    'refresh() picks up rows inserted behind the provider\'s back',
    () async {
      final provider = SessionProvider();
      await provider.loadSessions();
      expect(provider.sessions, isEmpty);

      // Insert directly at the DB layer — the provider doesn't know.
      await DatabaseService.insertSession(_session('inserted externally'));

      await provider.refresh();
      expect(
        provider.sessions,
        hasLength(1),
        reason: 'refresh must reload from the DB even after initial load',
      );
    },
  );

  test('loadSessions() is still a one-shot guard', () async {
    final provider = SessionProvider();
    await provider.loadSessions();

    await DatabaseService.insertSession(_session('inserted externally'));

    await provider.loadSessions();
    expect(
      provider.sessions,
      isEmpty,
      reason: 'loadSessions stays guarded; only refresh() reloads',
    );
  });

  group('updateSession', () {
    test('replaces the session in place and persists it', () async {
      final provider = SessionProvider();
      await provider.loadSessions();
      final original = _session('before edit');
      await provider.addSession(original);

      await provider.updateSession(
        original.copyWith(sessionGoal: 'edited goal', notes: 'after edit'),
      );

      expect(provider.sessions.single.sessionGoal, 'edited goal');
      expect(provider.sessions.single.notes, 'after edit');
      expect(provider.sessions.single.id, original.id);

      // Survives a cold reload — it actually hit the DB.
      final fresh = SessionProvider();
      await fresh.loadSessions();
      expect(fresh.sessions.single.sessionGoal, 'edited goal');
    });

    test('re-sorts by date when the edit moves the session', () async {
      final provider = SessionProvider();
      await provider.loadSessions();
      final older = _session('older', day: 1);
      final newer = _session('newer', day: 5);
      await provider.addSession(older);
      await provider.addSession(newer);
      expect(provider.sessions.first.id, newer.id);

      // Move the older session past the newer one.
      await provider.updateSession(older.copyWith(date: DateTime(2026, 7, 9)));

      expect(
        provider.sessions.first.id,
        older.id,
        reason: 'list must stay sorted date-descending after an edit',
      );
    });

    test('notifies listeners', () async {
      final provider = SessionProvider();
      await provider.loadSessions();
      final original = _session('watch me');
      await provider.addSession(original);

      var notified = false;
      provider.addListener(() => notified = true);
      await provider.updateSession(original.copyWith(sessionGoal: 'g'));

      expect(notified, isTrue);
    });
  });

  group('custom drill tags', () {
    test('addCustomTag persists and appears after built-in drills', () async {
      final provider = SessionProvider();
      await provider.loadSessions();

      await provider.addCustomTag('Shadow Footwork');

      expect(provider.customTags, ['Shadow Footwork']);
      expect(provider.allDrillTypes, [...kDrillTypes, 'Shadow Footwork']);

      // Cold reload sees it — persisted, not just in-memory.
      final fresh = SessionProvider();
      await fresh.loadSessions();
      expect(fresh.customTags, ['Shadow Footwork']);
    });

    test(
      'addCustomTag trims and ignores blank, duplicate, and built-in names',
      () async {
        final provider = SessionProvider();
        await provider.loadSessions();

        await provider.addCustomTag('  ');
        await provider.addCustomTag('Footwork'); // built-in
        await provider.addCustomTag('Deception');
        await provider.addCustomTag(' Deception '); // duplicate after trim

        expect(provider.customTags, ['Deception']);
      },
    );

    test('deleteCustomTag removes the tag', () async {
      final provider = SessionProvider();
      await provider.loadSessions();
      await provider.addCustomTag('Deception');

      await provider.deleteCustomTag('Deception');

      expect(provider.customTags, isEmpty);
      expect(provider.allDrillTypes, kDrillTypes);
    });

    test('custom tag changes notify listeners', () async {
      final provider = SessionProvider();
      await provider.loadSessions();

      var notifications = 0;
      provider.addListener(() => notifications++);
      await provider.addCustomTag('Deception');
      await provider.deleteCustomTag('Deception');

      expect(notifications, 2);
    });
  });

  group('sessionsPerWeek', () {
    // Friday, so the current week starts Monday 2026-07-06.
    final today = DateTime(2026, 7, 10);
    final currentWeekStart = DateTime(2026, 7, 6);
    final previousWeekStart = DateTime(2026, 6, 29);

    test(
      'counts a session that falls exactly on the week-start boundary',
      () async {
        final provider = SessionProvider();
        await provider.loadSessions();
        await DatabaseService.insertSession(
          _session('on boundary', day: currentWeekStart.day),
        );
        await provider.refresh();

        final buckets = provider.sessionsPerWeek(weeks: 2, now: today);

        expect(buckets[currentWeekStart], 1);
      },
    );

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
      await DatabaseService.insertSession(
        TrainingSession(
          id: const Uuid().v4(),
          date: currentWeekStart.subtract(const Duration(days: 21)),
          durationMinutes: 60,
          drills: const ['Footwork'],
          intensity: 3,
        ),
      );
      await provider.refresh();

      final buckets = provider.sessionsPerWeek(weeks: 2, now: today);

      expect(
        buckets.values.every((count) => count == 0),
        isTrue,
        reason: 'session 3 weeks back must not appear in a 2-week window',
      );
    });
  });

  group('avgIntensityPerWeek', () {
    final today = DateTime(2026, 7, 10);
    final currentWeekStart = DateTime(2026, 7, 6);

    test('averages multiple sessions in the same week', () async {
      final provider = SessionProvider();
      await provider.loadSessions();
      await DatabaseService.insertSession(
        TrainingSession(
          id: const Uuid().v4(),
          date: currentWeekStart,
          durationMinutes: 60,
          drills: const ['Footwork'],
          intensity: 2,
        ),
      );
      await DatabaseService.insertSession(
        TrainingSession(
          id: const Uuid().v4(),
          date: currentWeekStart.add(const Duration(days: 1)),
          durationMinutes: 60,
          drills: const ['Smash'],
          intensity: 4,
        ),
      );
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

    test('ignores sessions with null intensity', () async {
      final provider = SessionProvider();
      await provider.loadSessions();
      await DatabaseService.insertSession(
        TrainingSession(
          id: const Uuid().v4(),
          date: currentWeekStart,
          durationMinutes: 60,
          drills: const ['Footwork'],
          intensity: 4,
        ),
      );
      // Post-redesign session: no intensity rating.
      await DatabaseService.insertSession(
        TrainingSession(
          id: const Uuid().v4(),
          date: currentWeekStart.add(const Duration(days: 1)),
          durationMinutes: 60,
          drills: const ['Smash'],
          sessionGoal: 'unrated',
        ),
      );
      await provider.refresh();

      final buckets = provider.avgIntensityPerWeek(weeks: 1, now: today);

      expect(
        buckets[currentWeekStart],
        4.0,
        reason: 'unrated sessions must not drag the average toward zero',
      );
    });

    test('a week with only unrated sessions reports 0.0', () async {
      final provider = SessionProvider();
      await provider.loadSessions();
      await DatabaseService.insertSession(
        TrainingSession(
          id: const Uuid().v4(),
          date: currentWeekStart,
          durationMinutes: 60,
          drills: const ['Footwork'],
        ),
      );
      await provider.refresh();

      final buckets = provider.avgIntensityPerWeek(weeks: 1, now: today);

      expect(buckets[currentWeekStart], 0.0);
    });
  });

  group('avgGoalAchievementPerWeek', () {
    final today = DateTime(2026, 7, 10);
    final currentWeekStart = DateTime(2026, 7, 6);
    final previousWeekStart = DateTime(2026, 6, 29);

    test('buckets scores into the correct weeks and averages them', () async {
      final provider = SessionProvider();
      await provider.loadSessions();
      await DatabaseService.insertSession(
        TrainingSession(
          id: const Uuid().v4(),
          date: currentWeekStart,
          durationMinutes: 60,
          drills: const ['Footwork'],
          goalAchievementScore: 2,
        ),
      );
      await DatabaseService.insertSession(
        TrainingSession(
          id: const Uuid().v4(),
          date: currentWeekStart.add(const Duration(days: 2)),
          durationMinutes: 60,
          drills: const ['Smash'],
          goalAchievementScore: 5,
        ),
      );
      await DatabaseService.insertSession(
        TrainingSession(
          id: const Uuid().v4(),
          date: previousWeekStart,
          durationMinutes: 60,
          drills: const ['Clear'],
          goalAchievementScore: 1,
        ),
      );
      await provider.refresh();

      final buckets = provider.avgGoalAchievementPerWeek(weeks: 2, now: today);

      expect(buckets[currentWeekStart], 3.5);
      expect(buckets[previousWeekStart], 1.0);
    });

    test('reports 0 for empty weeks and spans the requested window', () async {
      final provider = SessionProvider();
      await provider.loadSessions();

      final buckets = provider.avgGoalAchievementPerWeek(weeks: 8, now: today);

      expect(buckets, hasLength(8));
      expect(buckets.values.every((avg) => avg == 0.0), isTrue);
    });
  });
}
