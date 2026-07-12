import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/match_log.dart';
import '../theme/app_theme.dart';
import 'star_rating.dart';

class MatchLogCard extends StatelessWidget {
  final MatchLog log;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const MatchLogCard({super.key, required this.log, this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('EEE, d MMM yyyy').format(log.date),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  _ResultChip(isWin: log.isWin),
                  if (onDelete != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onDelete,
                      child: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                log.scores.isEmpty
                    ? 'vs ${log.opponent}'
                    : 'vs ${log.opponent} · ${log.scores}',
              ),
              if (log.eventContext.isNotEmpty)
                Text(
                  log.eventContext,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text(
                    'Readiness ',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  StarRating(value: log.readinessScore, size: 14),
                  if (log.videoRef != null) ...[
                    const Spacer(),
                    const Icon(
                      Icons.videocam_outlined,
                      size: 18,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  final bool isWin;

  const _ResultChip({required this.isWin});

  @override
  Widget build(BuildContext context) {
    final color = isWin ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isWin ? 'WIN' : 'LOSS',
        style: TextStyle(
          color: color.shade700,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
