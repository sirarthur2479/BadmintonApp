import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/match_log_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/opponent_stats.dart';
import 'opponent_profile_screen.dart';

/// Everyone the player has logged matches against, newest-first, with the
/// head-to-head at a glance. Tapping a row opens the opponent profile.
class OpponentsScreen extends StatelessWidget {
  const OpponentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final logs = context.watch<MatchLogProvider>().matchLogs;
    final opponents = opponentsFrom(logs);
    return Scaffold(
      appBar: AppBar(title: const Text('Opponents')),
      body: opponents.isEmpty
          ? const Center(
              child: Text(
                'No opponents yet.\nLog a match to start profiling!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: opponents.length,
              itemBuilder: (context, index) {
                final opponent = opponents[index];
                return Card(
                  child: ListTile(
                    title: Text(opponent.displayName),
                    subtitle: Text(
                      '${opponent.wins}W – ${opponent.losses}L · '
                      '${opponent.matches} '
                      '${opponent.matches == 1 ? 'match' : 'matches'} · '
                      'last ${DateFormat('d MMM yyyy').format(opponent.lastPlayed)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OpponentProfileScreen(
                          opponentKey: opponent.key,
                          displayName: opponent.displayName,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
