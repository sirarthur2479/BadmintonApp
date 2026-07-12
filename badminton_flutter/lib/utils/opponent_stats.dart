/// Deterministic opponent profiling (pool #10): pure aggregation over match
/// logs + point records. Rates are null whenever their denominator is zero —
/// a NaN can never leak (the build_summary convention). Works with whatever
/// data exists: logs-only opponents get a head-to-head and nothing else.
library;

import '../models/match_log.dart';
import '../models/point_record.dart';

/// Exact, case-insensitive opponent identity (no fuzzy merging).
String opponentKey(String name) => name.trim().toLowerCase();

/// One row in the opponents list.
class OpponentSummary {
  final String key;
  final String displayName;
  final int matches;
  final int wins;
  final int losses;
  final DateTime lastPlayed;

  const OpponentSummary({
    required this.key,
    required this.displayName,
    required this.matches,
    required this.wins,
    required this.losses,
    required this.lastPlayed,
  });
}

/// Groups match logs per opponent, newest-first. The display name is the
/// spelling used in the most recent log.
List<OpponentSummary> opponentsFrom(List<MatchLog> logs) {
  final byKey = <String, List<MatchLog>>{};
  for (final log in logs) {
    byKey.putIfAbsent(opponentKey(log.opponent), () => []).add(log);
  }
  final summaries = [
    for (final entry in byKey.entries)
      () {
        final sorted = [...entry.value]
          ..sort((a, b) => b.date.compareTo(a.date));
        return OpponentSummary(
          key: entry.key,
          displayName: sorted.first.opponent,
          matches: sorted.length,
          wins: sorted.where((l) => l.isWin).length,
          losses: sorted.where((l) => !l.isWin).length,
          lastPlayed: sorted.first.date,
        );
      }(),
  ];
  summaries.sort((a, b) => b.lastPlayed.compareTo(a.lastPlayed));
  return summaries;
}

/// A rally-length band with its point count and win rate.
class RallyBand {
  final String label;
  final int count;

  /// Null when [count] is zero.
  final double? winRate;

  const RallyBand({required this.label, required this.count, this.winRate});
}

/// Everything the opponent profile screen and the facts builder consume.
class OpponentStats {
  final String key;
  final int matches;
  final int wins;
  final int losses;
  final int taggedPoints;
  final double? pointsWonRate;
  final double? serveWinRate;
  final double? receiveWinRate;
  final double? pressurePointsWonRate;
  final int pressurePoints;

  /// short (≤4) / medium (5–9) / long (10+); bands with zero points are
  /// omitted entirely.
  final List<RallyBand> rallyBands;

  /// Shot → count maps, sorted by count descending.
  final Map<String, int> opponentWinnersByShot;
  final Map<String, int> playerUnforcedByShot;
  final Map<String, int> opponentUnforcedByShot;

  /// "zone|side" label → count, sorted by count descending.
  final Map<String, int> endingZoneCounts;

  const OpponentStats({
    required this.key,
    required this.matches,
    required this.wins,
    required this.losses,
    required this.taggedPoints,
    this.pointsWonRate,
    this.serveWinRate,
    this.receiveWinRate,
    this.pressurePointsWonRate,
    this.pressurePoints = 0,
    this.rallyBands = const [],
    this.opponentWinnersByShot = const {},
    this.playerUnforcedByShot = const {},
    this.opponentUnforcedByShot = const {},
    this.endingZoneCounts = const {},
  });

  /// Computes the profile for one opponent [key]. [logs] may contain other
  /// opponents (they are filtered); [points] must belong to the given logs
  /// or be a superset — only points of this opponent's logs count.
  factory OpponentStats.compute({
    required List<MatchLog> logs,
    required List<PointRecord> points,
    required String key,
  }) {
    final ownLogs = [
      for (final log in logs)
        if (opponentKey(log.opponent) == key) log,
    ];
    final ownLogIds = {for (final log in ownLogs) log.id};
    final own = [
      for (final p in points)
        if (ownLogIds.contains(p.matchLogId)) p,
    ];

    double? rate(int numerator, int denominator) =>
        denominator == 0 ? null : numerator / denominator;

    final won = own.where((p) => p.winner == 'player').length;

    final served = own.where((p) => p.server == 'player').toList();
    final received = own.where((p) => p.server == 'opponent').toList();

    // Pressure: either side already at 18+ BEFORE the point. The stored
    // score is after the point, so subtract the winner's increment.
    bool isPressure(PointRecord p) {
      final playerBefore =
          p.winner == 'player' ? p.playerScore - 1 : p.playerScore;
      final opponentBefore =
          p.winner == 'opponent' ? p.opponentScore - 1 : p.opponentScore;
      return playerBefore >= 18 || opponentBefore >= 18;
    }

    final pressure = own.where(isPressure).toList();

    RallyBand? band(String label, bool Function(int) inBand) {
      final banded = [
        for (final p in own)
          if (p.rallyLength != null && inBand(p.rallyLength!)) p,
      ];
      if (banded.isEmpty) return null;
      return RallyBand(
        label: label,
        count: banded.length,
        winRate: rate(
          banded.where((p) => p.winner == 'player').length,
          banded.length,
        ),
      );
    }

    Map<String, int> shotCounts(bool Function(PointRecord) where) {
      final counts = <String, int>{};
      for (final p in own.where(where)) {
        final shot = p.endingShot;
        if (shot == null) continue;
        counts[shot] = (counts[shot] ?? 0) + 1;
      }
      final entries = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return {for (final e in entries) e.key: e.value};
    }

    final zoneCounts = <String, int>{};
    for (final p in own) {
      if (p.endingZone == null) continue;
      final label = p.endingSide == null
          ? p.endingZone!
          : '${p.endingZone}|${p.endingSide}';
      zoneCounts[label] = (zoneCounts[label] ?? 0) + 1;
    }
    final zoneEntries = zoneCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return OpponentStats(
      key: key,
      matches: ownLogs.length,
      wins: ownLogs.where((l) => l.isWin).length,
      losses: ownLogs.where((l) => !l.isWin).length,
      taggedPoints: own.length,
      pointsWonRate: rate(won, own.length),
      serveWinRate: rate(
        served.where((p) => p.winner == 'player').length,
        served.length,
      ),
      receiveWinRate: rate(
        received.where((p) => p.winner == 'player').length,
        received.length,
      ),
      pressurePoints: pressure.length,
      pressurePointsWonRate: rate(
        pressure.where((p) => p.winner == 'player').length,
        pressure.length,
      ),
      rallyBands: [
        ?band('short', (n) => n <= 4),
        ?band('medium', (n) => n >= 5 && n <= 9),
        ?band('long', (n) => n >= 10),
      ],
      // Attribution: winner/forcedError endings belong to the side that WON
      // the point; an unforcedError to the side that LOST it.
      opponentWinnersByShot: shotCounts(
        (p) => p.winner == 'opponent' && p.endingType != 'unforcedError',
      ),
      playerUnforcedByShot: shotCounts(
        (p) => p.winner == 'opponent' && p.endingType == 'unforcedError',
      ),
      opponentUnforcedByShot: shotCounts(
        (p) => p.winner == 'player' && p.endingType == 'unforcedError',
      ),
      endingZoneCounts: {for (final e in zoneEntries) e.key: e.value},
    );
  }
}
