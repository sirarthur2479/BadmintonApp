class TournamentMatch {
  final String id;
  final String tournamentId;
  final String opponent;
  final List<String> scores; // e.g. ["21-15", "21-18"]
  final bool isWin;
  final String? notes;

  const TournamentMatch({
    required this.id,
    required this.tournamentId,
    required this.opponent,
    required this.scores,
    required this.isWin,
    this.notes,
  });

  TournamentMatch copyWith({
    String? id,
    String? tournamentId,
    String? opponent,
    List<String>? scores,
    bool? isWin,
    String? notes,
  }) {
    return TournamentMatch(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      opponent: opponent ?? this.opponent,
      scores: scores ?? this.scores,
      isWin: isWin ?? this.isWin,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tournamentId': tournamentId,
      'opponent': opponent,
      'scores': scores.join('|'),
      'isWin': isWin ? 1 : 0,
      'notes': notes,
    };
  }

  factory TournamentMatch.fromMap(Map<String, dynamic> map) {
    final scoresStr = map['scores'] as String? ?? '';
    return TournamentMatch(
      id: map['id'] as String,
      tournamentId: map['tournamentId'] as String,
      opponent: map['opponent'] as String,
      scores: scoresStr.isEmpty ? [] : scoresStr.split('|'),
      isWin: (map['isWin'] as int) == 1,
      notes: map['notes'] as String?,
    );
  }
}

class Tournament {
  final String id;
  final String name;
  final DateTime date;
  final String location;
  final String format; // e.g. Round Robin, Knockout
  final List<TournamentMatch> matches;

  const Tournament({
    required this.id,
    required this.name,
    required this.date,
    required this.location,
    required this.format,
    this.matches = const [],
  });

  int get wins => matches.where((m) => m.isWin).length;
  int get losses => matches.where((m) => !m.isWin).length;

  Tournament copyWith({
    String? id,
    String? name,
    DateTime? date,
    String? location,
    String? format,
    List<TournamentMatch>? matches,
  }) {
    return Tournament(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      location: location ?? this.location,
      format: format ?? this.format,
      matches: matches ?? this.matches,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'date': date.toIso8601String(),
      'location': location,
      'format': format,
    };
  }

  factory Tournament.fromMap(Map<String, dynamic> map,
      {List<TournamentMatch> matches = const []}) {
    return Tournament(
      id: map['id'] as String,
      name: map['name'] as String,
      date: DateTime.parse(map['date'] as String),
      location: map['location'] as String,
      format: map['format'] as String,
      matches: matches,
    );
  }
}
