import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/session_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/streak_badge.dart';
import '../../widgets/stat_card.dart';
import '../train/log_session_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Badminton Trainer'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Image.asset(
              'assets/icon/icon.png',
              width: 28,
              height: 28,
              errorBuilder: (_, _, _) => const Icon(Icons.sports_tennis),
            ),
          ),
        ],
      ),
      body: Consumer<SessionProvider>(
        builder: (context, provider, _) {
          final streak = provider.currentStreak;
          final thisWeek = provider.sessionsThisWeek;
          final thisMonth = provider.sessionsThisMonth;
          final latest = provider.latestSession;

          return RefreshIndicator(
            onRefresh: () => provider.loadSessions(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Greeting
                Text(
                  _greeting(),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, d MMMM').format(DateTime.now()),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),

                // Streak
                Row(
                  children: [
                    const Text(
                      'Training streak',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    StreakBadge(streak: streak),
                  ],
                ),
                const SizedBox(height: 20),

                // Stat cards
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    StatCard(
                      icon: Icons.calendar_today,
                      label: 'This week',
                      value: '$thisWeek',
                    ),
                    StatCard(
                      icon: Icons.bar_chart,
                      label: 'This month',
                      value: '$thisMonth',
                      color: AppTheme.primaryLight,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Last session
                if (latest != null) ...[
                  Text(
                    'Last session',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEE, d MMM').format(latest.date),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${latest.durationMinutes} min · Intensity ${latest.intensity}/5',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (latest.drills.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              latest.drills.join(', '),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppTheme.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  const Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.fitness_center,
                                size: 40, color: AppTheme.textSecondary),
                            SizedBox(height: 8),
                            Text(
                              'No sessions yet.\nTap + to log your first session!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LogSessionScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Log Session'),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning!';
    if (hour < 17) return 'Good afternoon!';
    return 'Good evening!';
  }
}
