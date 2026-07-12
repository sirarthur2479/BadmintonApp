import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/point_record.dart';
import '../../providers/match_log_provider.dart';
import '../../providers/point_record_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/opponent_stats.dart';
import '../../widgets/match_log_card.dart';
import 'log_match_screen.dart';

/// Per-opponent tactical profile (pool #10): head-to-head from the match
/// logs, point-derived stats from whatever rallies have been tagged, and
/// the match history. Works fully offline; sections without data show a
/// "tag points to unlock" note instead of zeros.
class OpponentProfileScreen extends StatefulWidget {
  const OpponentProfileScreen({
    super.key,
    required this.opponentKey,
    required this.displayName,
  });

  final String opponentKey;
  final String displayName;

  @override
  State<OpponentProfileScreen> createState() => _OpponentProfileScreenState();
}

class _OpponentProfileScreenState extends State<OpponentProfileScreen> {
  List<PointRecord>? _allPoints;

  @override
  void initState() {
    super.initState();
    context.read<PointRecordProvider>().allPoints().then((points) {
      if (mounted) setState(() => _allPoints = points);
    });
  }

  String _percent(double rate) => '${(rate * 100).round()}%';

  Widget _section(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _statLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _shotList(Map<String, int> counts) {
    return Column(
      children: [
        for (final entry in counts.entries)
          _statLine(entry.key, '${entry.value}'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final logs = context.watch<MatchLogProvider>().matchLogs;
    final ownLogs = [
      for (final log in logs)
        if (opponentKey(log.opponent) == widget.opponentKey) log,
    ];
    final stats = OpponentStats.compute(
      logs: logs,
      points: _allPoints ?? const [],
      key: widget.opponentKey,
    );
    final tagged = stats.taggedPoints > 0;

    return Scaffold(
      appBar: AppBar(title: Text(widget.displayName)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _section('Head-to-head', [
            _statLine(
              'Record',
              '${stats.wins}W – ${stats.losses}L · ${stats.matches} '
                  '${stats.matches == 1 ? 'match' : 'matches'}',
            ),
            if (stats.pointsWonRate != null)
              _statLine(
                'Points won',
                '${_percent(stats.pointsWonRate!)} · '
                    '${stats.taggedPoints} points tagged',
              ),
          ]),
          if (!tagged)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Tag points from a match video to unlock serve, rally and '
                  'shot breakdowns.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ),
          if (tagged) ...[
            _section('Serve vs receive', [
              if (stats.serveWinRate != null)
                _statLine('On our serve', _percent(stats.serveWinRate!)),
              if (stats.receiveWinRate != null)
                _statLine('Receiving', _percent(stats.receiveWinRate!)),
              if (stats.pressurePointsWonRate != null)
                _statLine(
                  'Pressure points (18+)',
                  '${_percent(stats.pressurePointsWonRate!)} of '
                      '${stats.pressurePoints}',
                ),
            ]),
            if (stats.rallyBands.isNotEmpty)
              _section('Rally length', [
                for (final band in stats.rallyBands)
                  _statLine(
                    '${band.label} (${band.count})',
                    band.winRate == null ? '—' : _percent(band.winRate!),
                  ),
              ]),
            if (stats.opponentWinnersByShot.isNotEmpty)
              _section(
                'Their finishing shots',
                [_shotList(stats.opponentWinnersByShot)],
              ),
            if (stats.playerUnforcedByShot.isNotEmpty)
              _section(
                'Our unforced errors',
                [_shotList(stats.playerUnforcedByShot)],
              ),
            if (stats.opponentUnforcedByShot.isNotEmpty)
              _section(
                'Their unforced errors',
                [_shotList(stats.opponentUnforcedByShot)],
              ),
            if (stats.endingZoneCounts.isNotEmpty)
              _section('Where points ended', [
                _shotList(stats.endingZoneCounts),
              ]),
          ],
          const SizedBox(height: 8),
          Text(
            'Match history',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          for (final log in ownLogs)
            MatchLogCard(
              log: log,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LogMatchScreen(existing: log),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
