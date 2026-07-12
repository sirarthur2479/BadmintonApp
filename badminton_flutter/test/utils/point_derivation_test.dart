import 'package:flutter_test/flutter_test.dart';
import 'package:badminton_flutter/models/point_record.dart';
import 'package:badminton_flutter/utils/point_derivation.dart';

PointRecord _point(
  int game,
  int indexInGame,
  String winner, {
  int playerScore = 0,
  int opponentScore = 0,
}) => PointRecord(
  id: 'pt-$game-$indexInGame',
  matchLogId: 'log-1',
  game: game,
  indexInGame: indexInGame,
  server: 'player',
  winner: winner,
  playerScore: playerScore,
  opponentScore: opponentScore,
  endingType: 'winner',
);

/// Builds a sequence of points from winner initials, deriving scores/games
/// the way the tagging screen would.
List<PointRecord> _sequence(String winners) {
  final points = <PointRecord>[];
  for (final ch in winners.split('')) {
    final winner = ch == 'p' ? 'player' : 'opponent';
    final game = currentGame(points);
    final gamePoints = points.where((pt) => pt.game == game).toList();
    final score = scoreAfter(gamePoints, winner);
    points.add(
      _point(
        game,
        gamePoints.length + 1,
        winner,
        playerScore: score.player,
        opponentScore: score.opponent,
      ),
    );
  }
  return points;
}

void main() {
  group('serverForNext', () {
    test('first server of game 1 is the chosen side', () {
      expect(serverForNext([], 'opponent'), 'opponent');
      expect(serverForNext([], 'player'), 'player');
    });

    test('winner of a rally serves the next rally', () {
      final points = _sequence('po');
      expect(serverForNext(points, 'player'), 'opponent');
      expect(serverForNext(_sequence('op'), 'player'), 'player');
    });

    test('winner of a game serves first in the next game', () {
      // Player takes game 1 to 21-0: the 22nd rally is game 2, and the
      // player serves it because they won the game.
      final points = _sequence('p' * 21);
      expect(currentGame(points), 2);
      expect(serverForNext(points, 'opponent'), 'player');
    });
  });

  group('scoreAfter', () {
    test('score increments for the winning side only', () {
      final gamePoints = _sequence('ppo');
      final after = scoreAfter(gamePoints, 'opponent');
      expect(after.player, 2);
      expect(after.opponent, 2);
    });

    test('starts a game at 1-0 or 0-1', () {
      final after = scoreAfter([], 'player');
      expect(after.player, 1);
      expect(after.opponent, 0);
    });
  });

  group('isGameOver', () {
    test('game ends at 21 with two clear', () {
      expect(isGameOver(21, 19), isTrue);
      expect(isGameOver(19, 21), isTrue);
      expect(isGameOver(21, 15), isTrue);
    });

    test('game continues at 20-20 until two clear', () {
      expect(isGameOver(20, 20), isFalse);
      expect(isGameOver(21, 20), isFalse);
      expect(isGameOver(22, 20), isTrue);
      expect(isGameOver(23, 22), isFalse);
    });

    test('game hard-caps at 30-29', () {
      expect(isGameOver(29, 29), isFalse);
      expect(isGameOver(30, 29), isTrue);
      expect(isGameOver(29, 30), isTrue);
    });

    test('short scores are not over', () {
      expect(isGameOver(0, 0), isFalse);
      expect(isGameOver(19, 18), isFalse);
    });
  });

  group('currentGame', () {
    test('starts at game 1', () {
      expect(currentGame([]), 1);
    });

    test('stays in game 1 mid-game', () {
      expect(currentGame(_sequence('ppopo')), 1);
    });

    test('advances after a completed game', () {
      expect(currentGame(_sequence('p' * 21)), 2);
    });

    test('advances after a deuce game completes', () {
      // 20-20 then two player points: 22-20 ends the game.
      final winners = '${'po' * 20}pp';
      expect(currentGame(_sequence(winners)), 2);
    });

    test('reaches game 3 after two completed games', () {
      final winners = 'p' * 21 + 'o' * 21;
      final points = _sequence(winners);
      expect(currentGame(points), 3);
      // Opponent won game 2, so opponent serves game 3 first.
      expect(serverForNext(points, 'player'), 'opponent');
    });
  });
}
