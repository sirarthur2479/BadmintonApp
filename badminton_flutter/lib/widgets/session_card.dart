import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/session.dart';
import '../theme/app_theme.dart';

class SessionCard extends StatelessWidget {
  final TrainingSession session;
  final VoidCallback? onDelete;

  const SessionCard({super.key, required this.session, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('EEE, d MMM yyyy').format(session.date),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _IntensityDots(intensity: session.intensity),
                if (onDelete != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onDelete,
                    child: const Icon(Icons.delete_outline,
                        size: 20, color: AppTheme.textSecondary),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.timer_outlined,
                    size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${session.durationMinutes} min',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (session.drills.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: session.drills
                    .map((d) => Chip(
                          label: Text(d),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
            ],
            if (session.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                session.notes,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IntensityDots extends StatelessWidget {
  final int intensity;

  const _IntensityDots({required this.intensity});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < intensity;
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(left: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled
                ? AppTheme.intensityColor(intensity)
                : Colors.grey.shade300,
          ),
        );
      }),
    );
  }
}
