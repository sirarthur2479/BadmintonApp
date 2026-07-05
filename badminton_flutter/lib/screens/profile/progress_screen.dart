import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../providers/session_provider.dart';
import '../../theme/app_theme.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: Consumer<SessionProvider>(
        builder: (context, provider, _) {
          final sessionsPerWeek = provider.sessionsPerWeek(weeks: 8);
          final intensityPerWeek = provider.avgIntensityPerWeek(weeks: 8);
          final weeks = sessionsPerWeek.keys.toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary stats
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: 'Total sessions',
                      value: '${provider.sessions.length}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      label: 'Current streak',
                      value: '${provider.currentStreak} days',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      label: 'Best streak',
                      value: '${provider.bestStreak} days',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Sessions per week bar chart
              Text('Sessions per week',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (sessionsPerWeek.values.isEmpty
                            ? 5
                            : sessionsPerWeek.values
                                    .reduce((a, b) => a > b ? a : b) +
                                1)
                        .toDouble(),
                    barGroups: List.generate(weeks.length, (i) {
                      final count =
                          sessionsPerWeek[weeks[i]]?.toDouble() ?? 0;
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: count,
                            color: AppTheme.primary,
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
                                color: AppTheme.textSecondary),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, _) {
                            final idx = v.toInt();
                            if (idx < 0 || idx >= weeks.length) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              DateFormat('d/M').format(weeks[idx]),
                              style: const TextStyle(
                                  fontSize: 9,
                                  color: AppTheme.textSecondary),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Avg intensity line chart
              Text('Average intensity per week',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: 5,
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(weeks.length, (i) {
                          final avg =
                              intensityPerWeek[weeks[i]] ?? 0.0;
                          return FlSpot(i.toDouble(), avg);
                        }),
                        isCurved: true,
                        color: AppTheme.primaryLight,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppTheme.primaryLight.withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          getTitlesWidget: (v, _) => Text(
                            v.toInt().toString(),
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.textSecondary),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, _) {
                            final idx = v.toInt();
                            if (idx < 0 || idx >= weeks.length) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              DateFormat('d/M').format(weeks[idx]),
                              style: const TextStyle(
                                  fontSize: 9,
                                  color: AppTheme.textSecondary),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      show: true,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: Colors.grey.shade200,
                        strokeWidth: 1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
