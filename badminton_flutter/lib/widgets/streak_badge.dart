import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StreakBadge extends StatelessWidget {
  final int streak;

  const StreakBadge({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: streak > 0 ? AppTheme.primary : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department,
            color: streak > 0 ? Colors.orange.shade300 : Colors.grey,
            size: 22,
          ),
          const SizedBox(width: 6),
          Text(
            '$streak day${streak == 1 ? '' : 's'}',
            style: TextStyle(
              color: streak > 0 ? Colors.white : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
