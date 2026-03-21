import 'package:uuid/uuid.dart';
import '../models/session.dart';

List<TrainingSession> buildSampleSessions() {
  final now = DateTime.now();
  final uuid = const Uuid();

  // Helper to create a date relative to today
  DateTime daysAgo(int days) =>
      DateTime(now.year, now.month, now.day - days);

  return [
    // Week 1 (most recent)
    TrainingSession(
      id: uuid.v4(),
      date: daysAgo(1),
      durationMinutes: 90,
      drills: ['Footwork', 'Smash', 'Multi-Feed'],
      intensity: 4,
      notes: 'Good smash session. Worked on jump smash timing.',
    ),
    TrainingSession(
      id: uuid.v4(),
      date: daysAgo(3),
      durationMinutes: 60,
      drills: ['Footwork', 'Net Play', 'Serve'],
      intensity: 3,
      notes: 'Focus on net kill consistency.',
    ),
    TrainingSession(
      id: uuid.v4(),
      date: daysAgo(5),
      durationMinutes: 75,
      drills: ['Match Play', 'Footwork'],
      intensity: 5,
      notes: 'Tournament prep match. Won 3-1 sets.',
    ),
    TrainingSession(
      id: uuid.v4(),
      date: daysAgo(6),
      durationMinutes: 45,
      drills: ['Fitness', 'Footwork'],
      intensity: 4,
      notes: 'Shadow footwork circuit x5.',
    ),

    // Week 2
    TrainingSession(
      id: uuid.v4(),
      date: daysAgo(8),
      durationMinutes: 90,
      drills: ['Drop Shot', 'Clear', 'Smash'],
      intensity: 4,
      notes: 'Focused on drop shot deception.',
    ),
    TrainingSession(
      id: uuid.v4(),
      date: daysAgo(10),
      durationMinutes: 60,
      drills: ['Serve', 'Net Play'],
      intensity: 2,
      notes: 'Light session. Serve accuracy drills.',
    ),
    TrainingSession(
      id: uuid.v4(),
      date: daysAgo(12),
      durationMinutes: 90,
      drills: ['Multi-Feed', 'Smash', 'Footwork'],
      intensity: 5,
      notes: 'Hard multi-shuttle session. Very tired by the end.',
    ),
    TrainingSession(
      id: uuid.v4(),
      date: daysAgo(13),
      durationMinutes: 60,
      drills: ['Match Play'],
      intensity: 4,
      notes: 'Friendly matches. Tried cross-court tactics.',
    ),
    TrainingSession(
      id: uuid.v4(),
      date: daysAgo(14),
      durationMinutes: 30,
      drills: ['Footwork'],
      intensity: 2,
      notes: 'Recovery session.',
    ),

    // Week 3
    TrainingSession(
      id: uuid.v4(),
      date: daysAgo(16),
      durationMinutes: 75,
      drills: ['Footwork', 'Drive', 'Net Play'],
      intensity: 3,
      notes: 'Drive and net play combination.',
    ),
    TrainingSession(
      id: uuid.v4(),
      date: daysAgo(18),
      durationMinutes: 90,
      drills: ['Smash', 'Clear', 'Multi-Feed'],
      intensity: 5,
      notes: 'Best session this month — smash accuracy 80%.',
    ),
    TrainingSession(
      id: uuid.v4(),
      date: daysAgo(20),
      durationMinutes: 60,
      drills: ['Serve', 'Drop Shot'],
      intensity: 3,
      notes: 'Coach feedback: flick serve needs more deception.',
    ),
    TrainingSession(
      id: uuid.v4(),
      date: daysAgo(21),
      durationMinutes: 45,
      drills: ['Footwork', 'Fitness'],
      intensity: 3,
      notes: 'Agility ladder + shadow.',
    ),

    // Week 4
    TrainingSession(
      id: uuid.v4(),
      date: daysAgo(23),
      durationMinutes: 90,
      drills: ['Match Play', 'Footwork'],
      intensity: 4,
      notes: 'Won 2, lost 1 in club ladder matches.',
    ),
    TrainingSession(
      id: uuid.v4(),
      date: daysAgo(25),
      durationMinutes: 60,
      drills: ['Net Play', 'Drop Shot', 'Smash'],
      intensity: 3,
      notes: 'Net kill drill — getting more consistent.',
    ),
    TrainingSession(
      id: uuid.v4(),
      date: daysAgo(26),
      durationMinutes: 90,
      drills: ['Multi-Feed', 'Footwork'],
      intensity: 5,
      notes: 'Hard conditioning session.',
    ),
    TrainingSession(
      id: uuid.v4(),
      date: daysAgo(27),
      durationMinutes: 45,
      drills: ['Clear', 'Smash'],
      intensity: 3,
      notes: 'Clear and smash sequence practice.',
    ),
    TrainingSession(
      id: uuid.v4(),
      date: daysAgo(28),
      durationMinutes: 60,
      drills: ['Serve', 'Net Play', 'Footwork'],
      intensity: 2,
      notes: 'Technique focus — slow and deliberate.',
    ),
  ];
}
