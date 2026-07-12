import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/match_log_provider.dart';
import '../../services/export_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/opponent_stats.dart';
import '../../widgets/confirm_delete.dart';
import '../../widgets/match_log_card.dart';
import 'log_match_screen.dart';
import 'opponent_profile_screen.dart';
import 'tag_points_screen.dart';

/// The Match Logs tab's app-bar export button: shares every log as one
/// Markdown document (same consumption path as the session export).
class MatchLogExportAction extends StatelessWidget {
  const MatchLogExportAction({super.key});

  @override
  Widget build(BuildContext context) {
    final logs = context.watch<MatchLogProvider>().matchLogs;
    return IconButton(
      icon: const Icon(Icons.ios_share),
      tooltip: 'Export as Markdown',
      onPressed: logs.isEmpty
          ? null
          : () => SharePlus.instance.share(
              ShareParams(
                text: ExportService.bulkExportMatchLogs(logs: logs),
                subject: 'Match log export',
              ),
            ),
    );
  }
}

/// The Match Logs tab body: newest-first list with pull-to-refresh.
class MatchLogsTab extends StatelessWidget {
  /// Test seam; point tagging is mobile-only, like the upload features.
  final bool? webOverride;

  const MatchLogsTab({super.key, this.webOverride});

  @override
  Widget build(BuildContext context) {
    final isWeb = webOverride ?? kIsWeb;
    return Consumer<MatchLogProvider>(
      builder: (context, provider, _) {
        final logs = provider.matchLogs;
        if (logs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.sports_tennis,
                  size: 56,
                  color: AppTheme.textSecondary,
                ),
                SizedBox(height: 12),
                Text(
                  'No match logs yet.\nLog your next match to start reflecting!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: provider.refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return MatchLogCard(
                log: log,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LogMatchScreen(existing: log),
                  ),
                ),
                onOpponentTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OpponentProfileScreen(
                      opponentKey: opponentKey(log.opponent),
                      displayName: log.opponent,
                    ),
                  ),
                ),
                onTagPoints: log.videoRef == null || isWeb
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TagPointsScreen(log: log),
                        ),
                      ),
                onDelete: () async {
                  final confirmed = await confirmDelete(
                    context,
                    title: 'Delete match log?',
                  );
                  if (confirmed) provider.deleteMatchLog(log.id);
                },
              );
            },
          ),
        );
      },
    );
  }
}
