/// Pre-worded opponent facts (pool #10): the deterministic half of the
/// tactical brief, mirroring badminton_track's build_summary rule — every
/// number is computed here and worded here; the LLM may narrate but never
/// invent or re-derive statistics. Any stat with a null rate is SKIPPED,
/// never rendered as null/NaN/0%.
library;

import 'opponent_stats.dart';

String _percent(double rate) => '${(rate * 100).round()}%';

const _bandPhrases = {
  'short': 'Short rallies (4 shots or fewer)',
  'medium': 'Medium rallies (5–9 shots)',
  'long': 'Long rallies (10+ shots)',
};

String _shotSummary(Map<String, int> counts) => [
  for (final entry in counts.entries) '${entry.key} (${entry.value})',
].join(', ');

/// Ordered, human-readable, stable fact strings for one opponent.
List<String> opponentFacts(String displayName, OpponentStats stats) {
  final facts = <String>[
    'Head-to-head vs $displayName: won ${stats.wins} of ${stats.matches} '
        '${stats.matches == 1 ? 'match' : 'matches'}.',
  ];

  if (stats.pointsWonRate != null) {
    facts.add(
      'Across ${stats.taggedPoints} tagged points we win '
      '${_percent(stats.pointsWonRate!)}.',
    );
  }
  if (stats.serveWinRate != null) {
    facts.add(
      'On our serve we win ${_percent(stats.serveWinRate!)} of points '
      '(${stats.servePointsWon}/${stats.servePoints} tagged).',
    );
  }
  if (stats.receiveWinRate != null) {
    facts.add('Receiving we win ${_percent(stats.receiveWinRate!)} of points.');
  }
  for (final band in stats.rallyBands) {
    if (band.winRate == null) continue;
    final phrase = _bandPhrases[band.label] ?? band.label;
    facts.add(
      '$phrase: we win ${_percent(band.winRate!)} (of ${band.count}).',
    );
  }
  if (stats.opponentWinnersByShot.isNotEmpty) {
    facts.add(
      'Their winners come mostly from: '
      '${_shotSummary(stats.opponentWinnersByShot)}.',
    );
  }
  if (stats.playerUnforcedByShot.isNotEmpty) {
    facts.add(
      'Our unforced errors come mostly from: '
      '${_shotSummary(stats.playerUnforcedByShot)}.',
    );
  }
  if (stats.opponentUnforcedByShot.isNotEmpty) {
    facts.add(
      'Their unforced errors come mostly from: '
      '${_shotSummary(stats.opponentUnforcedByShot)}.',
    );
  }
  if (stats.pressurePointsWonRate != null) {
    facts.add(
      'Pressure points (either side 18+): we win '
      '${_percent(stats.pressurePointsWonRate!)} (of ${stats.pressurePoints}).',
    );
  }
  return facts;
}
