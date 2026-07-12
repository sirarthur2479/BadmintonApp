import 'package:flutter_test/flutter_test.dart';
import 'package:badminton_flutter/utils/opponent_facts.dart';
import 'package:badminton_flutter/utils/opponent_stats.dart';

const _rich = OpponentStats(
  key: 'ken t.',
  matches: 5,
  wins: 3,
  losses: 2,
  taggedPoints: 40,
  pointsWonRate: 0.55,
  serveWinRate: 0.583333,
  receiveWinRate: 0.45,
  servePoints: 24,
  servePointsWon: 14,
  receivePoints: 16,
  receivePointsWon: 7,
  pressurePointsWonRate: 0.25,
  pressurePoints: 4,
  rallyBands: [
    RallyBand(label: 'short', count: 12, winRate: 0.75),
    RallyBand(label: 'long', count: 6, winRate: 1 / 3),
  ],
  opponentWinnersByShot: {'smash': 6, 'drop': 2},
  playerUnforcedByShot: {'net': 4},
  opponentUnforcedByShot: {'lift': 3},
  endingZoneCounts: {'rearLeft|player': 5},
);

const _logsOnly = OpponentStats(
  key: 'mia w.',
  matches: 2,
  wins: 0,
  losses: 2,
  taggedPoints: 0,
);

void main() {
  group('opponentFacts', () {
    test('renders head to head, serve/receive and rally bands with counts', () {
      final facts = opponentFacts('Ken T.', _rich);

      expect(
        facts,
        contains('Head-to-head vs Ken T.: won 3 of 5 matches.'),
      );
      expect(
        facts,
        contains('On our serve we win 58% of points (14/24 tagged).'),
      );
      expect(facts, contains('Receiving we win 45% of points.'));
      expect(
        facts,
        contains('Short rallies (4 shots or fewer): we win 75% (of 12).'),
      );
      expect(
        facts,
        contains('Long rallies (10+ shots): we win 33% (of 6).'),
      );
      expect(
        facts,
        contains('Their winners come mostly from: smash (6), drop (2).'),
      );
      expect(
        facts,
        contains('Our unforced errors come mostly from: net (4).'),
      );
      expect(
        facts,
        contains('Pressure points (either side 18+): we win 25% (of 4).'),
      );
    });

    test('null rates are skipped, never rendered', () {
      final facts = opponentFacts('Mia W.', _logsOnly);

      expect(facts, contains('Head-to-head vs Mia W.: won 0 of 2 matches.'));
      expect(facts.join('\n'), isNot(contains('null')));
      expect(facts.join('\n'), isNot(contains('NaN')));
      expect(facts.join('\n'), isNot(contains('serve')));
      expect(facts.join('\n'), isNot(contains('rall')));
    });

    test('percentages are whole numbers', () {
      final facts = opponentFacts('Ken T.', _rich).join('\n');

      expect(facts, isNot(contains('58.3')));
      expect(facts, isNot(contains('33.3')));
    });
  });
}
