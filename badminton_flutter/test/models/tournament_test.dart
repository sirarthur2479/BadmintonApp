import 'package:flutter_test/flutter_test.dart';

import 'package:badminton_flutter/models/tournament.dart';

void main() {
  group('TournamentMatch toMap/fromMap', () {
    test('round-trips a win with multiple scores and notes', () {
      final match = const TournamentMatch(
        id: 'match-1',
        tournamentId: 'tourney-1',
        opponent: 'Alex Chen',
        scores: ['21-15', '18-21', '21-19'],
        isWin: true,
        notes: 'Close third set.',
      );

      final restored = TournamentMatch.fromMap(match.toMap());

      expect(restored.id, match.id);
      expect(restored.tournamentId, match.tournamentId);
      expect(restored.opponent, match.opponent);
      expect(restored.scores, match.scores);
      expect(restored.isWin, isTrue);
      expect(restored.notes, match.notes);
    });

    test('round-trips a loss with no notes and no scores', () {
      final match = const TournamentMatch(
        id: 'match-2',
        tournamentId: 'tourney-1',
        opponent: 'Sam Lee',
        scores: [],
        isWin: false,
      );

      final restored = TournamentMatch.fromMap(match.toMap());

      expect(restored.scores, isEmpty);
      expect(restored.isWin, isFalse);
      expect(restored.notes, isNull);
    });
  });

  group('Tournament toMap/fromMap', () {
    test('round-trips with matches passed in separately', () {
      final matches = [
        const TournamentMatch(
          id: 'match-1',
          tournamentId: 'tourney-1',
          opponent: 'Alex Chen',
          scores: ['21-15', '21-18'],
          isWin: true,
        ),
        const TournamentMatch(
          id: 'match-2',
          tournamentId: 'tourney-1',
          opponent: 'Sam Lee',
          scores: ['19-21', '15-21'],
          isWin: false,
        ),
      ];
      final tournament = Tournament(
        id: 'tourney-1',
        name: 'Regional Juniors',
        date: DateTime(2026, 7, 4),
        location: 'City Sports Hall',
        format: 'Round Robin',
        matches: matches,
      );

      final restored = Tournament.fromMap(tournament.toMap(), matches: matches);

      expect(restored.id, tournament.id);
      expect(restored.name, tournament.name);
      expect(restored.date, tournament.date);
      expect(restored.location, tournament.location);
      expect(restored.format, tournament.format);
      expect(restored.matches, matches);
    });

    test('wins and losses count matches correctly', () {
      final tournament = Tournament(
        id: 'tourney-2',
        name: 'Club Ladder',
        date: DateTime(2026, 7, 1),
        location: 'Local Club',
        format: 'Knockout',
        matches: const [
          TournamentMatch(
            id: 'm1',
            tournamentId: 'tourney-2',
            opponent: 'A',
            scores: ['21-10'],
            isWin: true,
          ),
          TournamentMatch(
            id: 'm2',
            tournamentId: 'tourney-2',
            opponent: 'B',
            scores: ['15-21'],
            isWin: false,
          ),
          TournamentMatch(
            id: 'm3',
            tournamentId: 'tourney-2',
            opponent: 'C',
            scores: ['21-19'],
            isWin: true,
          ),
        ],
      );

      expect(tournament.wins, 2);
      expect(tournament.losses, 1);
    });
  });
}
