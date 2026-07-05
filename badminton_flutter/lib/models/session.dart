import 'dart:convert';

class TrainingSession {
  final String id;
  final DateTime date;
  final int durationMinutes;
  final List<String> drills;
  final int intensity; // 1–5
  final String notes;
  final String? photoPath;

  const TrainingSession({
    required this.id,
    required this.date,
    required this.durationMinutes,
    required this.drills,
    required this.intensity,
    this.notes = '',
    this.photoPath,
  });

  TrainingSession copyWith({
    String? id,
    DateTime? date,
    int? durationMinutes,
    List<String>? drills,
    int? intensity,
    String? notes,
    String? photoPath,
  }) {
    return TrainingSession(
      id: id ?? this.id,
      date: date ?? this.date,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      drills: drills ?? this.drills,
      intensity: intensity ?? this.intensity,
      notes: notes ?? this.notes,
      photoPath: photoPath ?? this.photoPath,
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
      intensity: map['intensity'] as int,
      notes: map['notes'] as String? ?? '',
      photoPath: map['photoPath'] as String?,
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
