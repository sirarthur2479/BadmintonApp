import 'package:flutter_test/flutter_test.dart';
import 'package:badminton_flutter/models/point_record.dart';

void main() {
  group('PointRecord map round-trip', () {
    final full = PointRecord(
      id: 'pt-1',
      matchLogId: 'log-1',
      game: 2,
      indexInGame: 15,
      server: 'player',
      winner: 'opponent',
      playerScore: 7,
      opponentScore: 8,
      rallyLength: 12,
      endingType: 'unforcedError',
      endingShot: 'smash',
      endingZone: 'rearLeft',
      endingSide: 'player',
      videoTimestampMs: 754300,
    );

    test('toMap/fromMap round-trips a fully-populated point', () {
      final restored = PointRecord.fromMap(full.toMap());

      expect(restored.id, full.id);
      expect(restored.matchLogId, full.matchLogId);
      expect(restored.game, full.game);
      expect(restored.indexInGame, full.indexInGame);
      expect(restored.server, full.server);
      expect(restored.winner, full.winner);
      expect(restored.playerScore, full.playerScore);
      expect(restored.opponentScore, full.opponentScore);
      expect(restored.rallyLength, full.rallyLength);
      expect(restored.endingType, full.endingType);
      expect(restored.endingShot, full.endingShot);
      expect(restored.endingZone, full.endingZone);
      expect(restored.endingSide, full.endingSide);
      expect(restored.videoTimestampMs, full.videoTimestampMs);
    });

    test('nullable fields survive a round-trip when unset', () {
      final bare = PointRecord(
        id: 'pt-2',
        matchLogId: 'log-1',
        game: 1,
        indexInGame: 1,
        server: 'opponent',
        winner: 'player',
        playerScore: 1,
        opponentScore: 0,
        endingType: 'winner',
      );

      final restored = PointRecord.fromMap(bare.toMap());

      expect(restored.rallyLength, isNull);
      expect(restored.endingShot, isNull);
      expect(restored.endingZone, isNull);
      expect(restored.endingSide, isNull);
      expect(restored.videoTimestampMs, isNull);
    });

    test('fromMap applies defaults for missing optional keys', () {
      final point = PointRecord.fromMap({
        'id': 'pt-3',
        'matchLogId': 'log-1',
        'game': 1,
        'indexInGame': 3,
        'server': 'player',
        'winner': 'player',
        'playerScore': 2,
        'opponentScore': 1,
        'endingType': 'forcedError',
      });

      expect(point.rallyLength, isNull);
      expect(point.endingShot, isNull);
      expect(point.endingZone, isNull);
      expect(point.endingSide, isNull);
      expect(point.videoTimestampMs, isNull);
      expect(point.shots, isEmpty);
    });
  });
}
