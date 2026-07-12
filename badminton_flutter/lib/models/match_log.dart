/// A standalone per-match reflection log (pool idea #9).
///
/// Distinct from the tournament-scoped [TournamentMatch] rows: not tied to a
/// tournamentId, and carries the pre-match gameplan/readiness and post-match
/// reflection that drive improvement. Player scoping happens server-side via
/// the /players/{id}/match-logs routes; the local table is single-player,
/// same as sessions.
class MatchLog {
  final String id;
  final DateTime date;
  final String opponent;

  /// Free-text setting, e.g. "Practice", "League round 3", "Tournament R16".
  final String eventContext;

  /// Free-form scores string, e.g. "21-15, 18-21, 21-19".
  final String scores;
  final bool isWin;

  /// Pre-match plan.
  final String gameplan;

  /// Pre-match readiness, 1–5 (mirrors goalAchievementScore's scale).
  final int readinessScore;

  /// Post-match: what worked / what broke down.
  final String performanceNotes;
  final String keyMoments;

  /// Path or URL of a recording of this match, when one exists.
  final String? videoRef;

  const MatchLog({
    required this.id,
    required this.date,
    required this.opponent,
    this.eventContext = '',
    this.scores = '',
    required this.isWin,
    this.gameplan = '',
    this.readinessScore = 3,
    this.performanceNotes = '',
    this.keyMoments = '',
    this.videoRef,
  });

  MatchLog copyWith({
    String? id,
    DateTime? date,
    String? opponent,
    String? eventContext,
    String? scores,
    bool? isWin,
    String? gameplan,
    int? readinessScore,
    String? performanceNotes,
    String? keyMoments,
    String? videoRef,
  }) {
    return MatchLog(
      id: id ?? this.id,
      date: date ?? this.date,
      opponent: opponent ?? this.opponent,
      eventContext: eventContext ?? this.eventContext,
      scores: scores ?? this.scores,
      isWin: isWin ?? this.isWin,
      gameplan: gameplan ?? this.gameplan,
      readinessScore: readinessScore ?? this.readinessScore,
      performanceNotes: performanceNotes ?? this.performanceNotes,
      keyMoments: keyMoments ?? this.keyMoments,
      videoRef: videoRef ?? this.videoRef,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'opponent': opponent,
      'eventContext': eventContext,
      'scores': scores,
      'isWin': isWin ? 1 : 0,
      'gameplan': gameplan,
      'readinessScore': readinessScore,
      'performanceNotes': performanceNotes,
      'keyMoments': keyMoments,
      'videoRef': videoRef,
    };
  }

  factory MatchLog.fromMap(Map<String, dynamic> map) {
    return MatchLog(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      opponent: map['opponent'] as String,
      eventContext: map['eventContext'] as String? ?? '',
      scores: map['scores'] as String? ?? '',
      isWin: (map['isWin'] as int) == 1,
      gameplan: map['gameplan'] as String? ?? '',
      readinessScore: map['readinessScore'] as int? ?? 3,
      performanceNotes: map['performanceNotes'] as String? ?? '',
      keyMoments: map['keyMoments'] as String? ?? '',
      videoRef: map['videoRef'] as String?,
    );
  }
}
