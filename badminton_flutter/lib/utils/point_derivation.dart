/// Badminton rally-scoring derivations (pool #10 phase 1): the tagging
/// screen derives server, score, and game — the human only taps the winner.
///
/// Rules: every rally scores a point; the rally winner serves the next
/// rally; a game is won at 21 with two clear, hard-capped 30–29; the winner
/// of a game serves first in the next game. Because the game winner is by
/// definition the winner of its final rally, "last winner serves next"
/// holds across game boundaries too.
library;

import '../models/point_record.dart';

List<PointRecord> _ordered(List<PointRecord> points) =>
    [...points]..sort(
      (a, b) => a.game != b.game
          ? a.game.compareTo(b.game)
          : a.indexInGame.compareTo(b.indexInGame),
    );

/// Who serves the next rally. [game1FirstServer] is the only free choice
/// (asked once when tagging starts).
String serverForNext(List<PointRecord> soFar, String game1FirstServer) {
  if (soFar.isEmpty) return game1FirstServer;
  return _ordered(soFar).last.winner;
}

/// Running score within one game after [winner] takes the next point.
/// [gamePoints] are the points already recorded for that game.
({int player, int opponent}) scoreAfter(
  List<PointRecord> gamePoints,
  String winner,
) {
  var player = gamePoints.where((p) => p.winner == 'player').length;
  var opponent = gamePoints.length - player;
  if (winner == 'player') {
    player++;
  } else {
    opponent++;
  }
  return (player: player, opponent: opponent);
}

/// 21 with two clear; 30 ends the game regardless (30–29 is a valid win).
bool isGameOver(int a, int b) {
  final hi = a > b ? a : b;
  final diff = (a - b).abs();
  if (hi >= 30) return true;
  return hi >= 21 && diff >= 2;
}

/// The 1-based game the NEXT point belongs to.
int currentGame(List<PointRecord> soFar) {
  if (soFar.isEmpty) return 1;
  final ordered = _ordered(soFar);
  final last = ordered.last;
  return isGameOver(last.playerScore, last.opponentScore)
      ? last.game + 1
      : last.game;
}
