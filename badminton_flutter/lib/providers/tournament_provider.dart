import 'package:flutter/foundation.dart';
import '../models/tournament.dart';
import '../services/database_service.dart';

class TournamentProvider extends ChangeNotifier {
  List<Tournament> _tournaments = [];
  bool _loaded = false;

  List<Tournament> get tournaments => _tournaments;

  Future<void> loadTournaments() async {
    if (_loaded) return;
    _tournaments = await DatabaseService.getTournaments();
    _loaded = true;
    notifyListeners();
  }

  Future<void> addTournament(Tournament tournament) async {
    await DatabaseService.insertTournament(tournament);
    _tournaments = [tournament, ..._tournaments];
    notifyListeners();
  }

  Future<void> deleteTournament(String id) async {
    await DatabaseService.deleteTournament(id);
    _tournaments.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  Future<void> addMatch(TournamentMatch match) async {
    await DatabaseService.insertMatch(match);
    _tournaments = _tournaments.map((t) {
      if (t.id != match.tournamentId) return t;
      return t.copyWith(matches: [...t.matches, match]);
    }).toList();
    notifyListeners();
  }

  Future<void> deleteMatch(String matchId, String tournamentId) async {
    await DatabaseService.deleteMatch(matchId);
    _tournaments = _tournaments.map((t) {
      if (t.id != tournamentId) return t;
      return t.copyWith(
          matches: t.matches.where((m) => m.id != matchId).toList());
    }).toList();
    notifyListeners();
  }

  // ── Computed ──────────────────────────────────────────────────────────

  int get totalWins =>
      _tournaments.fold(0, (sum, t) => sum + t.wins);

  int get totalLosses =>
      _tournaments.fold(0, (sum, t) => sum + t.losses);

  int get totalMatches => totalWins + totalLosses;

  double get winRate =>
      totalMatches == 0 ? 0.0 : totalWins / totalMatches;
}
