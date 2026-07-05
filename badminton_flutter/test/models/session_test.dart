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

    test('drills with multiple entries survive the comma-join round-trip',
        () {
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
}
