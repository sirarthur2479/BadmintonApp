import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/session.dart';
import '../services/photo_store.dart';
import '../theme/app_theme.dart';
import 'star_rating.dart';

class SessionCard extends StatelessWidget {
  final TrainingSession session;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const SessionCard({
    super.key,
    required this.session,
    this.onEdit,
    this.onDelete,
  });

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
                // Goal-based sessions get achievement stars; older sessions
                // keep their legacy intensity dots.
                if (session.sessionGoal.isNotEmpty)
                  StarRating(
                    value: session.goalAchievementScore,
                    size: 14,
                    color: AppTheme.goalScoreColor(
                      session.goalAchievementScore,
                    ),
                  )
                else if (session.intensity != null)
                  _IntensityDots(intensity: session.intensity!),
                if (onEdit != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onEdit,
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
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
            Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${session.durationMinutes} min',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (session.sessionGoal.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.flag_outlined,
                    size: 14,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      session.sessionGoal,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (session.drills.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: session.drills
                    .map(
                      (d) => Chip(
                        label: Text(d),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                    .toList(),
              ),
            ],
            if (session.playerRemarks.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Player: ${session.playerRemarks}',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (session.coachRemarks.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Coach: ${session.coachRemarks}',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
            if (session.photoPath != null) ...[
              const SizedBox(height: 8),
              _PhotoThumbnail(storedPath: session.photoPath!),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  final String storedPath;

  const _PhotoThumbnail({required this.storedPath});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: PhotoStore.instance.resolvePath(storedPath),
      builder: (context, snapshot) {
        final path = snapshot.data;
        if (path == null) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) =>
                Dialog(child: InteractiveViewer(child: Image.file(File(path)))),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(path),
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
        );
      },
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
