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
}
