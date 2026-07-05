import 'dart:convert';

class TrainingSession {
  final String id;
  final DateTime date;
  final int durationMinutes;
  final List<String> drills;

  /// Legacy 1–5 effort rating. Sessions logged since the goal/reflection
  /// redesign store null; old rows keep their value for display.
  final int? intensity;
  final String notes;
  final String? photoPath;
  final String sessionGoal;
  final int goalAchievementScore; // 1–5
  final String playerRemarks;
  final String coachRemarks;
  final String reflectionAnswersJson;

  const TrainingSession({
    required this.id,
    required this.date,
    required this.durationMinutes,
    required this.drills,
    this.intensity,
    this.notes = '',
    this.photoPath,
    this.sessionGoal = '',
    this.goalAchievementScore = 3,
    this.playerRemarks = '',
    this.coachRemarks = '',
    this.reflectionAnswersJson = '[]',
  });

  TrainingSession copyWith({
    String? id,
    DateTime? date,
    int? durationMinutes,
    List<String>? drills,
    int? intensity,
    String? notes,
    String? photoPath,
    String? sessionGoal,
    int? goalAchievementScore,
    String? playerRemarks,
    String? coachRemarks,
    String? reflectionAnswersJson,
  }) {
    return TrainingSession(
      id: id ?? this.id,
      date: date ?? this.date,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      drills: drills ?? this.drills,
      intensity: intensity ?? this.intensity,
      notes: notes ?? this.notes,
      photoPath: photoPath ?? this.photoPath,
      sessionGoal: sessionGoal ?? this.sessionGoal,
      goalAchievementScore: goalAchievementScore ?? this.goalAchievementScore,
      playerRemarks: playerRemarks ?? this.playerRemarks,
      coachRemarks: coachRemarks ?? this.coachRemarks,
      reflectionAnswersJson:
          reflectionAnswersJson ?? this.reflectionAnswersJson,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'durationMinutes': durationMinutes,
      'drills': jsonEncode(drills),
      'intensity': intensity,
      'notes': notes,
      'photoPath': photoPath,
      'sessionGoal': sessionGoal,
      'goalAchievementScore': goalAchievementScore,
      'playerRemarks': playerRemarks,
      'coachRemarks': coachRemarks,
      'reflectionAnswersJson': reflectionAnswersJson,
    };
  }

  /// Drills are stored as a JSON array; rows written before the JSON
  /// migration used a comma-joined string, which stays readable.
  static List<String> _decodeDrills(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return [];
    if (trimmed.startsWith('[')) {
      return List<String>.from(jsonDecode(trimmed) as List);
    }
    return trimmed.split(',');
  }

  factory TrainingSession.fromMap(Map<String, dynamic> map) {
    return TrainingSession(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      durationMinutes: map['durationMinutes'] as int,
      drills: _decodeDrills(map['drills'] as String? ?? ''),
      intensity: map['intensity'] as int?,
      notes: map['notes'] as String? ?? '',
      photoPath: map['photoPath'] as String?,
      sessionGoal: map['sessionGoal'] as String? ?? '',
      goalAchievementScore: map['goalAchievementScore'] as int? ?? 3,
      playerRemarks: map['playerRemarks'] as String? ?? '',
      coachRemarks: map['coachRemarks'] as String? ?? '',
      reflectionAnswersJson: map['reflectionAnswersJson'] as String? ?? '[]',
    );
  }
}

const List<String> kDrillTypes = [
  'Footwork',
  'Smash',
  'Drop Shot',
  'Serve',
  'Net Play',
  'Clear',
  'Drive',
  'Multi-Feed',
  'Match Play',
  'Fitness',
];
