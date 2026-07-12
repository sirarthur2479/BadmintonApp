import 'package:flutter_test/flutter_test.dart';
import 'package:badminton_flutter/models/match_log.dart';
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
}
