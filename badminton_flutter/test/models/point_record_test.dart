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

  group('PointRecord shots reservation (shot-ready)', () {
    final withShots = PointRecord(
      id: 'pt-4',
      matchLogId: 'log-1',
      game: 1,
      indexInGame: 2,
      server: 'player',
      winner: 'player',
      playerScore: 2,
      opponentScore: 0,
      endingType: 'winner',
      shots: const [
        {'shotType': 'serve', 'side': 'player', 'timestampMs': 1000},
        {'shotType': 'smash', 'side': 'player', 'timestampMs': 3200},
      ],
    );

    test('toMap JSON-encodes shots to a string', () {
      final encoded = withShots.toMap()['shots'];
      expect(encoded, isA<String>());
      expect(encoded, contains('"shotType":"smash"'));
    });

    test('shots round-trip through toMap/fromMap', () {
      final restored = PointRecord.fromMap(withShots.toMap());
      expect(restored.shots, withShots.shots);
    });

    test('fromMap tolerates a missing shots key', () {
      final map = withShots.toMap()..remove('shots');
      expect(PointRecord.fromMap(map).shots, isEmpty);
    });

    test('fromMap tolerates a legacy empty shots string', () {
      final map = withShots.toMap()..['shots'] = '';
      expect(PointRecord.fromMap(map).shots, isEmpty);
    });

    test('shots default to empty', () {
      expect(withShots.copyWith(id: 'pt-5').shots, isNotEmpty);
      final bare = PointRecord(
        id: 'pt-6',
        matchLogId: 'log-1',
        game: 1,
        indexInGame: 1,
        server: 'player',
        winner: 'player',
        playerScore: 1,
        opponentScore: 0,
        endingType: 'winner',
      );
      expect(bare.shots, isEmpty);
    });
  });

  group('PointRecord copyWith', () {
    final base = PointRecord(
      id: 'pt-1',
      matchLogId: 'log-1',
      game: 1,
      indexInGame: 4,
      server: 'opponent',
      winner: 'player',
      playerScore: 3,
      opponentScore: 1,
      rallyLength: 6,
      endingType: 'winner',
      endingShot: 'drop',
      endingZone: 'frontRight',
      endingSide: 'opponent',
      videoTimestampMs: 42000,
    );

    test('copyWith replaces only the given fields', () {
      final edited = base.copyWith(winner: 'opponent', endingShot: 'net');

      expect(edited.winner, 'opponent');
      expect(edited.endingShot, 'net');
      // Everything else is untouched.
      expect(edited.id, base.id);
      expect(edited.matchLogId, base.matchLogId);
      expect(edited.game, base.game);
      expect(edited.indexInGame, base.indexInGame);
      expect(edited.server, base.server);
      expect(edited.playerScore, base.playerScore);
      expect(edited.opponentScore, base.opponentScore);
      expect(edited.rallyLength, base.rallyLength);
      expect(edited.endingType, base.endingType);
      expect(edited.endingZone, base.endingZone);
      expect(edited.endingSide, base.endingSide);
      expect(edited.videoTimestampMs, base.videoTimestampMs);
    });

    test('copyWith with no arguments is an identical copy', () {
      expect(base.copyWith().toMap(), base.toMap());
    });
  });

  group('PointRecord vocabularies', () {
    test('shared constants expose the closed enums', () {
      expect(PointRecord.sides, ['player', 'opponent']);
      expect(PointRecord.endingTypes, [
        'winner',
        'forcedError',
        'unforcedError',
      ]);
      expect(PointRecord.endingShots, hasLength(10));
      expect(PointRecord.endingShots.first, 'serve');
      expect(PointRecord.endingShots.last, 'other');
      expect(PointRecord.endingZones, [
        'frontLeft',
        'frontRight',
        'midLeft',
        'midRight',
        'rearLeft',
        'rearRight',
      ]);
    });
  });
}
