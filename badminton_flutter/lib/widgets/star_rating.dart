import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A 1–5 star score. Tappable when [onChanged] is set, display-only when
/// null.
class StarRating extends StatelessWidget {
  final int value;
  final ValueChanged<int>? onChanged;
  final double size;

  /// Fill color for the active stars; defaults to amber.
  final Color? color;

  const StarRating({
    super.key,
    required this.value,
    this.onChanged,
    this.size = 28,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final star = i + 1;
        final filled = star <= value;
        return GestureDetector(
          onTap: onChanged == null ? null : () => onChanged!(star),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              filled ? Icons.star : Icons.star_border,
              size: size,
              color: filled
                  ? (color ?? Colors.amber.shade600)
                  : AppTheme.textSecondary,
            ),
          ),
        );
      }),
    );
  }
}
