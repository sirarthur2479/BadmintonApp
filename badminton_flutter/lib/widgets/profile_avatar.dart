import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'local_image_provider_io.dart'
    if (dart.library.js_interop) 'local_image_provider_web.dart';

/// Player avatar that renders a locally stored photo (or a fallback icon).
class ProfileAvatar extends StatelessWidget {
  final String? photoPath;
  final double radius;

  const ProfileAvatar({super.key, this.photoPath, this.radius = 48});

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE8F5E9),
      backgroundImage: path != null ? localImageProvider(path) : null,
      child: path == null
          ? Icon(Icons.person, size: radius, color: AppTheme.primary)
          : null,
    );
  }
}
