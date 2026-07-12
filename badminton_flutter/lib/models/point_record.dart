import 'dart:convert';

/// One rally of a match (pool idea #10, stage-0 contract).
///
/// Point-level but *shot-ready*: [shots] is a reserved per-shot list that
/// phase-2 auto-tracking can fill without a schema migration — phase-1 hand
/// tagging always leaves it empty. Attached to a [MatchLog] via [matchLogId];
/// player scoping happens server-side through the nested
/// /players/{id}/match-logs/{logId}/points routes, same as match logs.
///
/// `endingShot` values stay mapped to the ShuttleSet stroke taxonomy
/// (research/shuttle-tracking.md) so a future learned classifier can drop in.
class PointRecord {
  final String id;
  final String matchLogId;

  /// 1-based game number (badminton: best of three).
  final int game;

  /// 1-based rally number within the game.
  final int indexInGame;

  /// Who served this rally: 'player' | 'opponent'. Derivable (the rally
  /// winner serves next) but stored so every record is self-contained.
  final String server;

  /// Who won the point: 'player' | 'opponent'.
  final String winner;

  /// Running score AFTER this point.
  final int playerScore;
  final int opponentScore;

  /// Shots in the rally, when known. Null = untagged.
  final int? rallyLength;

  /// How the rally ended: 'winner' | 'forcedError' | 'unforcedError'.
  /// A winner/forcedError belongs to the side that won the point; an
  /// unforcedError to the side that lost it.
  final String endingType;

  /// Shot that ended the rally, one of [endingShots]. Null = untagged.
  final String? endingShot;

  /// Coarse zone where the rally ended, one of [endingZones]. Null = untagged.
  final String? endingZone;

  /// Whose court half the rally ended on: 'player' | 'opponent'.
  final String? endingSide;

  /// Position in the match video, for deep links back to the footage.
  final int? videoTimestampMs;

  /// Reserved for phase 2: per-shot entries
  /// ({shotType, side, zone, timestampMs}). Always empty in phase 1.
  final List<Map<String, dynamic>> shots;

  const PointRecord({
    required this.id,
    required this.matchLogId,
    required this.game,
    required this.indexInGame,
    required this.server,
    required this.winner,
    required this.playerScore,
    required this.opponentScore,
    this.rallyLength,
    required this.endingType,
    this.endingShot,
    this.endingZone,
    this.endingSide,
    this.videoTimestampMs,
    this.shots = const [],
  });

  /// 'player' | 'opponent' — the two sides of every attribution field.
  static const sides = ['player', 'opponent'];

  static const endingTypes = ['winner', 'forcedError', 'unforcedError'];

  /// ShuttleSet-aligned stroke vocabulary.
  static const endingShots = [
    'serve',
    'clear',
    'drop',
    'smash',
    'net',
    'drive',
    'lift',
    'push',
    'block',
    'other',
  ];

  /// front/mid/rear × left/right, per half.
  static const endingZones = [
    'frontLeft',
    'frontRight',
    'midLeft',
    'midRight',
    'rearLeft',
    'rearRight',
  ];

  PointRecord copyWith({
    String? id,
    String? matchLogId,
    int? game,
    int? indexInGame,
    String? server,
    String? winner,
    int? playerScore,
    int? opponentScore,
    int? rallyLength,
    String? endingType,
    String? endingShot,
    String? endingZone,
    String? endingSide,
    int? videoTimestampMs,
    List<Map<String, dynamic>>? shots,
  }) {
    return PointRecord(
      id: id ?? this.id,
      matchLogId: matchLogId ?? this.matchLogId,
      game: game ?? this.game,
      indexInGame: indexInGame ?? this.indexInGame,
      server: server ?? this.server,
      winner: winner ?? this.winner,
      playerScore: playerScore ?? this.playerScore,
      opponentScore: opponentScore ?? this.opponentScore,
      rallyLength: rallyLength ?? this.rallyLength,
      endingType: endingType ?? this.endingType,
      endingShot: endingShot ?? this.endingShot,
      endingZone: endingZone ?? this.endingZone,
      endingSide: endingSide ?? this.endingSide,
      videoTimestampMs: videoTimestampMs ?? this.videoTimestampMs,
      shots: shots ?? this.shots,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'matchLogId': matchLogId,
      'game': game,
      'indexInGame': indexInGame,
      'server': server,
      'winner': winner,
      'playerScore': playerScore,
      'opponentScore': opponentScore,
      'rallyLength': rallyLength,
      'endingType': endingType,
      'endingShot': endingShot,
      'endingZone': endingZone,
      'endingSide': endingSide,
      'videoTimestampMs': videoTimestampMs,
      // Stored as a JSON string (the sessions-drills pattern) so the column
      // is a plain TEXT pass-through on every surface.
      'shots': jsonEncode(shots),
    };
  }

  factory PointRecord.fromMap(Map<String, dynamic> map) {
    return PointRecord(
      id: map['id'] as String,
      matchLogId: map['matchLogId'] as String,
      game: map['game'] as int,
      indexInGame: map['indexInGame'] as int,
      server: map['server'] as String,
      winner: map['winner'] as String,
      playerScore: map['playerScore'] as int,
      opponentScore: map['opponentScore'] as int,
      rallyLength: map['rallyLength'] as int?,
      endingType: map['endingType'] as String,
      endingShot: map['endingShot'] as String?,
      endingZone: map['endingZone'] as String?,
      endingSide: map['endingSide'] as String?,
      videoTimestampMs: map['videoTimestampMs'] as int?,
      shots: _decodeShots(map['shots']),
    );
  }

  static List<Map<String, dynamic>> _decodeShots(dynamic raw) {
    if (raw == null || raw is! String || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded.cast<Map<String, dynamic>>();
  }
}
