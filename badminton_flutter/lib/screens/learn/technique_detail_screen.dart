import 'package:flutter/material.dart';
import '../../models/technique.dart';
import '../../theme/app_theme.dart';

class TechniqueDetailScreen extends StatefulWidget {
  final Technique technique;

  const TechniqueDetailScreen({super.key, required this.technique});

  @override
  State<TechniqueDetailScreen> createState() => _TechniqueDetailScreenState();
}

class _TechniqueDetailScreenState extends State<TechniqueDetailScreen> {
  String _level = 'beginner';

  @override
  Widget build(BuildContext context) {
    final content = widget.technique.contentFor(_level);

    return Scaffold(
      appBar: AppBar(title: Text(widget.technique.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Category + difficulty row
          Row(
            children: [
              _Badge(
                widget.technique.category,
                color: const Color(0xFFE8F5E9),
                textColor: AppTheme.primary,
              ),
              const SizedBox(width: 8),
              _Badge(
                AppTheme.difficultyLabel(widget.technique.difficulty),
                color: AppTheme.difficultyColor(widget.technique.difficulty)
                    .withValues(alpha: 0.15),
                textColor:
                    AppTheme.difficultyColor(widget.technique.difficulty),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Animation placeholder
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_outline,
                      size: 56, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'Animation coming soon',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Level selector
          const Text(
            'Skill level',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'beginner', label: Text('Beginner')),
              ButtonSegment(value: 'intermediate', label: Text('Intermediate')),
              ButtonSegment(value: 'advanced', label: Text('Advanced')),
            ],
            selected: {_level},
            onSelectionChanged: (set) => setState(() => _level = set.first),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppTheme.primary;
                }
                return null;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return AppTheme.textPrimary;
              }),
            ),
          ),
          const SizedBox(height: 20),

          // Description
          _Section(
            title: 'Overview',
            child: Text(content.description,
                style: Theme.of(context).textTheme.bodyMedium),
          ),

          // Key tips
          _Section(
            title: 'Key Tips',
            child: Column(
              children: content.keyTips
                  .map((tip) => _BulletPoint(tip, icon: Icons.check_circle_outline,
                      color: AppTheme.primary))
                  .toList(),
            ),
          ),

          // Common mistakes
          _Section(
            title: 'Common Mistakes',
            child: Column(
              children: content.commonMistakes
                  .map((m) => _BulletPoint(m,
                      icon: Icons.cancel_outlined, color: Colors.red.shade400))
                  .toList(),
            ),
          ),

          // Related drills
          if (widget.technique.relatedDrills.isNotEmpty)
            _Section(
              title: 'Related Drills',
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: widget.technique.relatedDrills
                    .map((d) => Chip(label: Text(d)))
                    .toList(),
              ),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;

  const _BulletPoint(this.text, {required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _Badge(this.label, {required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
    );
  }
}
