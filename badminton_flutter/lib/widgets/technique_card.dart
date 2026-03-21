import 'package:flutter/material.dart';
import '../models/technique.dart';
import '../theme/app_theme.dart';

class TechniqueCard extends StatelessWidget {
  final Technique technique;
  final VoidCallback? onTap;

  const TechniqueCard({super.key, required this.technique, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.sports, color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      technique.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _CategoryBadge(category: technique.category),
                        const SizedBox(width: 6),
                        _DifficultyLabel(difficulty: technique.difficulty),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String category;

  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        category,
        style: const TextStyle(
          fontSize: 11,
          color: AppTheme.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _DifficultyLabel extends StatelessWidget {
  final String difficulty;

  const _DifficultyLabel({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    return Text(
      AppTheme.difficultyLabel(difficulty),
      style: TextStyle(
        fontSize: 11,
        color: AppTheme.difficultyColor(difficulty),
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
