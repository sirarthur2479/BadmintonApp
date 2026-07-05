import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Player avatar that renders a locally stored photo (or a fallback icon).
class ProfileAvatar extends StatelessWidget {
  final String? photoPath;
  final double radius;

  const ProfileAvatar({super.key, this.photoPath, this.radius = 48});

  @override
  Widget build(BuildContext context) {
    // Stub — image rendering driven by profile_avatar_test.dart
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE8F5E9),
      child: Icon(Icons.person, size: radius, color: AppTheme.primary),
    );
  }
}
