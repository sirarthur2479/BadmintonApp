import 'package:flutter_test/flutter_test.dart';
import 'package:badminton_flutter/models/match_log.dart';
import 'package:badminton_flutter/models/point_record.dart';
import 'package:badminton_flutter/utils/opponent_stats.dart';

MatchLog log(
  String id, {
  String opponent = 'Ken T.',
  bool isWin = true,
  DateTime? date,
}) => MatchLog(
  id: id,
  date: date ?? DateTime(2026, 7, 12),
  opponent: opponent,
  isWin: isWin,
);

void main() {
  group('opponentKey', () {
    test('trims and lowercases', () {
      expect(opponentKey('  Ken T. '), 'ken t.');
      expect(opponentKey('KEN T.'), 'ken t.');
      expect(opponentKey('ken t.'), opponentKey('Ken T.'));
    });
  });

  group('opponentsFrom', () {
    test('groups logs by key keeping the latest display spelling', () {
      final summaries = opponentsFrom([
        log('a', opponent: 'ken t.', date: DateTime(2026, 6, 1)),
        log('b', opponent: 'Ken T.', date: DateTime(2026, 7, 1), isWin: false),
        log('c', opponent: 'Mia W.', date: DateTime(2026, 5, 1)),
      ]);

      expect(summaries, hasLength(2));
      final ken = summaries.singleWhere((s) => s.key == 'ken t.');
      expect(ken.displayName, 'Ken T.', reason: 'most recent spelling wins');
      expect(ken.matches, 2);
      expect(ken.wins, 1);
      expect(ken.losses, 1);
      expect(ken.lastPlayed, DateTime(2026, 7, 1));
    });

    test('sorts by last played descending', () {
      final summaries = opponentsFrom([
        log('a', opponent: 'Old', date: DateTime(2026, 1, 1)),
        log('b', opponent: 'New', date: DateTime(2026, 7, 1)),
      ]);

      expect(summaries.first.displayName, 'New');
    });
  });

  group('OpponentStats head-to-head (logs only)', () {
    test('counts wins and losses for the key', () {
      final stats = OpponentStats.compute(
        logs: [
          log('a'),
          log('b', isWin: false),
          log('c', opponent: 'Mia W.'),
        ],
        points: const [],
        key: 'ken t.',
      );

      expect(stats.matches, 2);
      expect(stats.wins, 1);
      expect(stats.losses, 1);
      expect(stats.taggedPoints, 0);
    });

    test('all rates are null with zero tagged points', () {
      final stats = OpponentStats.compute(
        logs: [log('a')],
        points: const [],
        key: 'ken t.',
      );

      expect(stats.pointsWonRate, isNull);
      expect(stats.serveWinRate, isNull);
      expect(stats.receiveWinRate, isNull);
      expect(stats.pressurePointsWonRate, isNull);
      expect(stats.rallyBands, isEmpty);
      expect(stats.opponentWinnersByShot, isEmpty);
      expect(stats.playerUnforcedByShot, isEmpty);
      expect(stats.opponentUnforcedByShot, isEmpty);
      expect(stats.endingZoneCounts, isEmpty);
    });
  });

  group('OpponentStats from tagged points', () {
    var nextId = 0;
    PointRecord point({
      String matchLogId = 'a',
      String server = 'player',
      String winner = 'player',
      int playerScore = 1,
      int opponentScore = 0,
      int? rallyLength,
      String endingType = 'winner',
      String? endingShot,
      String? endingZone,
      String? endingSide,
    }) => PointRecord(
      id: 'pt-${nextId++}',
      matchLogId: matchLogId,
      game: 1,
      indexInGame: nextId,
      server: server,
      winner: winner,
      playerScore: playerScore,
      opponentScore: opponentScore,
      rallyLength: rallyLength,
      endingType: endingType,
      endingShot: endingShot,
      endingZone: endingZone,
      endingSide: endingSide,
    );

    OpponentStats compute(List<PointRecord> points) => OpponentStats.compute(
      logs: [log('a'), log('other', opponent: 'Mia W.')],
      points: points,
      key: 'ken t.',
    );

    test('points won rate counts only this opponents logs', () {
      final stats = compute([
        point(),
        point(winner: 'opponent'),
        point(matchLogId: 'other'), // Mia's log: excluded
      ]);

      expect(stats.taggedPoints, 2);
      expect(stats.pointsWonRate, 0.5);
    });

    test('serve and receive win rates split by server', () {
      final stats = compute([
        point(server: 'player', winner: 'player'),
        point(server: 'player', winner: 'opponent'),
        point(server: 'player', winner: 'player'),
        point(server: 'opponent', winner: 'opponent'),
      ]);

      expect(stats.serveWinRate, closeTo(2 / 3, 0.0001));
      expect(stats.receiveWinRate, 0.0);
    });

    test('rally bands bucket, exclude unknown lengths, omit empty bands', () {
      final stats = compute([
        point(rallyLength: 3, winner: 'player'),
        point(rallyLength: 4, winner: 'opponent'),
        point(rallyLength: 12, winner: 'player'),
        point(), // unknown length: excluded from bands
      ]);

      expect(stats.rallyBands.map((b) => b.label).toList(), [
        'short',
        'long',
      ], reason: 'no medium rallies tagged');
      final short = stats.rallyBands.first;
      expect(short.count, 2);
      expect(short.winRate, 0.5);
      expect(stats.rallyBands.last.count, 1);
    });

    test('opponent winners include forced errors, by shot, sorted', () {
      final stats = compute([
        point(winner: 'opponent', endingType: 'winner', endingShot: 'smash'),
        point(winner: 'opponent', endingType: 'winner', endingShot: 'smash'),
        point(
          winner: 'opponent',
          endingType: 'forcedError',
          endingShot: 'drop',
        ),
        // Their unforced error: NOT one of their winners.
        point(
          winner: 'player',
          endingType: 'unforcedError',
          endingShot: 'smash',
        ),
      ]);

      expect(stats.opponentWinnersByShot.keys.toList(), ['smash', 'drop']);
      expect(stats.opponentWinnersByShot['smash'], 2);
    });

    test('unforced errors attribute to the losing side', () {
      final stats = compute([
        // We lost the point on our own error:
        point(
          winner: 'opponent',
          endingType: 'unforcedError',
          endingShot: 'net',
        ),
        // They lost the point on their error:
        point(
          winner: 'player',
          endingType: 'unforcedError',
          endingShot: 'lift',
        ),
      ]);

      expect(stats.playerUnforcedByShot, {'net': 1});
      expect(stats.opponentUnforcedByShot, {'lift': 1});
    });

    test('pressure points use the pre-point score of eighteen plus', () {
      final stats = compute([
        // 17-17 before (18-17 after): not pressure.
        point(playerScore: 18, opponentScore: 17),
        // 18-17 before (19-17 after): pressure, won.
        point(playerScore: 19, opponentScore: 17),
        // 10-18 before (10-19 after): pressure, lost.
        point(winner: 'opponent', playerScore: 10, opponentScore: 19),
      ]);

      expect(stats.pressurePoints, 2);
      expect(stats.pressurePointsWonRate, 0.5);
    });

    test('zone counts pair zone with side and sort by count', () {
      final stats = compute([
        point(endingZone: 'rearLeft', endingSide: 'player'),
        point(endingZone: 'rearLeft', endingSide: 'player'),
        point(endingZone: 'frontRight', endingSide: 'opponent'),
        point(endingZone: 'midLeft'), // no side tagged
      ]);

      expect(stats.endingZoneCounts.keys.first, 'rearLeft|player');
      expect(stats.endingZoneCounts['rearLeft|player'], 2);
      expect(stats.endingZoneCounts['frontRight|opponent'], 1);
      expect(stats.endingZoneCounts['midLeft'], 1);
    });
  });
}
