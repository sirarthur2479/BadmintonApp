import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/match_log.dart';
import '../../models/point_record.dart';
import '../../providers/match_log_provider.dart';
import '../../providers/point_record_provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/analysis_server_provider.dart';
import '../../services/database_service.dart';
import '../../utils/opponent_facts.dart';
import '../../utils/opponent_stats.dart';
import '../../widgets/match_log_card.dart';
import 'log_match_screen.dart';
import 'opponent_brief_screen.dart';
import 'tag_points_screen.dart';

typedef BriefRequester =
    Future<String> Function(String opponent, List<String> facts);

/// Per-opponent tactical profile (pool #10): head-to-head from the match
/// logs, point-derived stats from whatever rallies have been tagged, and
/// the match history. Works fully offline; sections without data show a
/// "tag points to unlock" note instead of zeros.
class OpponentProfileScreen extends StatefulWidget {
  const OpponentProfileScreen({
    super.key,
    required this.opponentKey,
    required this.displayName,
    this.briefRequester,
    this.webOverride,
    this.tagScreenBuilder,
  });

  final String opponentKey;
  final String displayName;

  /// Test seam. Production default: web goes through the normal ApiService,
  /// mobile through the LAN analysis-server client; anything missing or
  /// failing falls back to the metrics-only brief.
  final BriefRequester? briefRequester;

  /// Test seams for the unlock deep link (tagging is off-web only).
  final bool? webOverride;
  final Widget Function(MatchLog log)? tagScreenBuilder;

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

  bool _briefBusy = false;

  Future<String> _defaultRequester(String opponent, List<String> facts) {
    if (kIsWeb) {
      return DatabaseService.webApi!.requestOpponentBrief(opponent, facts);
    }
    // Throws when the provider isn't in scope or the server isn't set up —
    // both land on the metrics-only fallback.
    return context.read<AnalysisServerProvider>().requestOpponentBrief(
      opponent,
      facts,
    );
  }

  Future<void> _openBrief(OpponentStats stats) async {
    setState(() => _briefBusy = true);
    final facts = opponentFacts(widget.displayName, stats);
    String markdown;
    var aiUnavailable = false;
    try {
      final requester = widget.briefRequester ?? _defaultRequester;
      markdown = await requester(widget.displayName, facts);
    } catch (_) {
      // The happy fallback path: no dialog, just the deterministic brief.
      markdown = metricsOnlyBrief(widget.displayName, stats);
      aiUnavailable = true;
    }
    if (!mounted) return;
    setState(() => _briefBusy = false);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OpponentBriefScreen(
          displayName: widget.displayName,
          markdown: markdown,
          aiUnavailable: aiUnavailable,
        ),
      ),
    );
  }

  /// The empty state doubles as the funnel: with a video-bearing log it is
  /// a one-tap deep link into the tagging screen; otherwise it names the
  /// missing step. On web (no tagging) it only explains where stats come
  /// from.
  Widget _unlockCard(List<MatchLog> ownLogs) {
    final isWeb = widget.webOverride ?? kIsWeb;
    MatchLog? videoLog;
    for (final log in ownLogs) {
      if (log.videoRef != null) {
        videoLog = log;
        break;
      }
    }

    if (isWeb) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text(
            'Point stats unlock once rallies are tagged in the mobile or '
            'laptop app.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }
    if (videoLog == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text(
            'Tag points from a match video to unlock serve, rally and shot '
            'breakdowns — add a video to a match log first.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }
    final log = videoLog;
    return Card(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                widget.tagScreenBuilder?.call(log) ??
                TagPointsScreen(log: log),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Tag points from the '
                  '${DateFormat('d MMM').format(log.date)} match video to '
                  'unlock serve, rally and shot breakdowns.',
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ElevatedButton.icon(
              onPressed: _briefBusy ? null : () => _openBrief(stats),
              icon: _briefBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.psychology_outlined),
              label: const Text('Tactical brief'),
            ),
          ),
          if (!tagged) _unlockCard(ownLogs),
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
