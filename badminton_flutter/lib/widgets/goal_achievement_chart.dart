import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import '../theme/app_theme.dart';

/// 8-week bar chart of the average goal-achievement score, bars colored by
/// how close the week came to its goals.
class GoalAchievementChart extends StatelessWidget {
  final int weeks;

  const GoalAchievementChart({super.key, this.weeks = 8});

  @override
  Widget build(BuildContext context) {
    final perWeek = context.watch<SessionProvider>().avgGoalAchievementPerWeek(
      weeks: weeks,
    );
    final weekStarts = perWeek.keys.toList();

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          minY: 0,
          maxY: 5,
          barGroups: List.generate(weekStarts.length, (i) {
            final avg = perWeek[weekStarts[i]] ?? 0.0;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: avg,
                  color: avg == 0
                      ? AppTheme.divider
                      : AppTheme.goalScoreColor(avg.round()),
                  width: 18,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= weekStarts.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    DateFormat('d/M').format(weekStarts[idx]),
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppTheme.textSecondary,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
        ),
      ),
    );
  }
}
