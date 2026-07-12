import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/match_log_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/confirm_delete.dart';
import '../../widgets/match_log_card.dart';

/// The Match Logs tab body: newest-first list with pull-to-refresh.
class MatchLogsTab extends StatelessWidget {
  const MatchLogsTab({super.key});

  @override
  Widget build(BuildContext context) {
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

/// Stand-in until LogMatchScreen lands (TASK-040).
class LogMatchPlaceholder extends StatelessWidget {
  const LogMatchPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Log Match')));
  }
}
