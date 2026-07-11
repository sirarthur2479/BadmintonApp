import 'package:flutter_test/flutter_test.dart';

import 'package:badminton_flutter/models/session.dart';

void main() {
  group('TrainingSession toMap/fromMap', () {
    test('round-trips a full session', () {
      final session = TrainingSession(
        id: 'session-1',
        date: DateTime(2026, 7, 10, 14, 30),
        durationMinutes: 90,
        drills: const ['Footwork', 'Smash', 'Net Play'],
        intensity: 4,
        notes: 'Worked on split-step timing.',
        photoPath: 'session_photos/session-1.jpg',
      );

      final restored = TrainingSession.fromMap(session.toMap());

      expect(restored.id, session.id);
      expect(restored.date, session.date);
      expect(restored.durationMinutes, session.durationMinutes);
      expect(restored.drills, session.drills);
      expect(restored.intensity, session.intensity);
      expect(restored.notes, session.notes);
      expect(restored.photoPath, session.photoPath);
    });

    test('round-trips a session with no drills and no photo', () {
      final session = TrainingSession(
        id: 'session-2',
        date: DateTime(2026, 7, 11),
        durationMinutes: 30,
        drills: const [],
        intensity: 1,
      );

      final restored = TrainingSession.fromMap(session.toMap());

      expect(restored.drills, isEmpty);
      expect(restored.photoPath, isNull);
      expect(restored.notes, '');
    });

    test('drills with multiple entries survive the storage round-trip', () {
      final session = TrainingSession(
        id: 'session-3',
        date: DateTime(2026, 7, 12),
        durationMinutes: 60,
        drills: const ['Drive', 'Clear', 'Multi-Feed', 'Match Play'],
        intensity: 3,
      );

      final restored = TrainingSession.fromMap(session.toMap());

      expect(restored.drills, ['Drive', 'Clear', 'Multi-Feed', 'Match Play']);
    });
  });

  group('drills JSON storage', () {
    test('round-trip preserves a tag containing a comma', () {
      final session = TrainingSession(
        id: 'session-4',
        date: DateTime(2026, 7, 13),
        durationMinutes: 45,
        drills: const ['Multi-feed, front court', 'Smash'],
        intensity: 2,
      );

      final restored = TrainingSession.fromMap(session.toMap());

      expect(restored.drills, ['Multi-feed, front court', 'Smash']);
    });

    test('toMap writes drills as a JSON array', () {
      final session = TrainingSession(
        id: 'session-5',
        date: DateTime(2026, 7, 13),
        durationMinutes: 45,
        drills: const ['Footwork', 'Smash'],
        intensity: 2,
      );

      expect(session.toMap()['drills'], '["Footwork","Smash"]');
    });

    test('toMap writes an empty drill list as an empty JSON array', () {
      final session = TrainingSession(
        id: 'session-6',
        date: DateTime(2026, 7, 13),
        durationMinutes: 45,
        drills: const [],
        intensity: 2,
      );

      expect(session.toMap()['drills'], '[]');
    });

    test('fromMap parses legacy comma-joined drills', () {
      final restored = TrainingSession.fromMap({
        'id': 'legacy-1',
        'date': DateTime(2026, 1, 5).toIso8601String(),
        'durationMinutes': 60,
        'drills': 'Footwork,Smash,Net Play',
        'intensity': 3,
        'notes': '',
        'photoPath': null,
      });

      expect(restored.drills, ['Footwork', 'Smash', 'Net Play']);
    });

    test('fromMap parses a legacy empty drills string as no drills', () {
      final restored = TrainingSession.fromMap({
        'id': 'legacy-2',
        'date': DateTime(2026, 1, 6).toIso8601String(),
        'durationMinutes': 60,
        'drills': '',
        'intensity': 3,
        'notes': '',
        'photoPath': null,
      });

      expect(restored.drills, isEmpty);
    });
  });

  group('goal and reflection fields', () {
    test('fromMap defaults new fields when keys are missing (legacy map)', () {
      final restored = TrainingSession.fromMap({
        'id': 'legacy-3',
        'date': DateTime(2026, 1, 7).toIso8601String(),
        'durationMinutes': 60,
        'drills': 'Footwork',
        'intensity': 4,
        'notes': 'old row',
        'photoPath': null,
      });

      expect(restored.sessionGoal, '');
      expect(restored.goalAchievementScore, 3);
      expect(restored.playerRemarks, '');
      expect(restored.coachRemarks, '');
      expect(restored.reflectionAnswersJson, '[]');
      expect(restored.intensity, 4);
    });

    test('goal and reflection fields survive toMap/fromMap round-trip', () {
      final session = TrainingSession(
        id: 'session-7',
        date: DateTime(2026, 7, 14),
        durationMinutes: 75,
        drills: const ['Net Play'],
        sessionGoal: 'Sharper net kills',
        goalAchievementScore: 4,
        playerRemarks: 'Kills felt crisp',
        coachRemarks: 'Watch the recovery step',
        reflectionAnswersJson:
            '[{"questionKey":"Why did you set this goal for today?","answer":"Coach picked it"}]',
      );

      final restored = TrainingSession.fromMap(session.toMap());

      expect(restored.sessionGoal, 'Sharper net kills');
      expect(restored.goalAchievementScore, 4);
      expect(restored.playerRemarks, 'Kills felt crisp');
      expect(restored.coachRemarks, 'Watch the recovery step');
      expect(restored.reflectionAnswersJson, session.reflectionAnswersJson);
    });

    test('null intensity survives the round-trip', () {
      final session = TrainingSession(
        id: 'session-8',
        date: DateTime(2026, 7, 15),
        durationMinutes: 60,
        drills: const ['Smash'],
        sessionGoal: 'Steeper smashes',
      );

      expect(session.intensity, isNull);
      expect(TrainingSession.fromMap(session.toMap()).intensity, isNull);
    });

    test('copyWith replaces each new field independently', () {
      final base = TrainingSession(
        id: 'session-9',
        date: DateTime(2026, 7, 16),
        durationMinutes: 60,
        drills: const ['Clear'],
      );

      expect(base.copyWith(sessionGoal: 'g').sessionGoal, 'g');
      expect(base.copyWith(goalAchievementScore: 5).goalAchievementScore, 5);
      expect(base.copyWith(playerRemarks: 'p').playerRemarks, 'p');
      expect(base.copyWith(coachRemarks: 'c').coachRemarks, 'c');
      expect(
        base.copyWith(reflectionAnswersJson: '[1]').reflectionAnswersJson,
        '[1]',
      );
      expect(base.copyWith(intensity: 2).intensity, 2);
      // Untouched fields stay put.
      final copy = base.copyWith(sessionGoal: 'g');
      expect(copy.id, base.id);
      expect(copy.goalAchievementScore, base.goalAchievementScore);
    });
  });

  group('analysis attachment (TASK-034)', () {
    test('round-trips report and court map paths', () {
      final session = TrainingSession(
        id: 'session-a',
        date: DateTime(2026, 7, 8),
        durationMinutes: 60,
        drills: const [],
        analysisReportPath: 'analysis/session-a/report.md',
        analysisCourtMapPath: 'analysis/session-a/court-map.png',
      );

      final restored = TrainingSession.fromMap(session.toMap());

      expect(restored.analysisReportPath, 'analysis/session-a/report.md');
      expect(restored.analysisCourtMapPath, 'analysis/session-a/court-map.png');
    });

    test('defaults to null and survives legacy maps without the keys', () {
      final legacy = TrainingSession(
        id: 'session-b',
        date: DateTime(2026, 7, 8),
        durationMinutes: 45,
        drills: const ['Smash'],
      ).toMap()
        ..remove('analysisReportPath')
        ..remove('analysisCourtMapPath');

      final restored = TrainingSession.fromMap(legacy);

      expect(restored.analysisReportPath, isNull);
      expect(restored.analysisCourtMapPath, isNull);
    });

    test('copyWith sets the attachment paths', () {
      final session = TrainingSession(
        id: 'session-c',
        date: DateTime(2026, 7, 8),
        durationMinutes: 30,
        drills: const [],
      );

      final updated = session.copyWith(
        analysisReportPath: 'r.md',
        analysisCourtMapPath: 'm.png',
      );

      expect(updated.analysisReportPath, 'r.md');
      expect(updated.analysisCourtMapPath, 'm.png');
      expect(updated.id, 'session-c');
    });
  });
}
