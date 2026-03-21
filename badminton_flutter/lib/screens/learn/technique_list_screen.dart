import 'package:flutter/material.dart';
import '../../data/techniques_seed.dart';
import '../../models/technique.dart';
import '../../theme/app_theme.dart';
import '../../widgets/technique_card.dart';
import 'technique_detail_screen.dart';

class TechniqueListScreen extends StatefulWidget {
  const TechniqueListScreen({super.key});

  @override
  State<TechniqueListScreen> createState() => _TechniqueListScreenState();
}

class _TechniqueListScreenState extends State<TechniqueListScreen> {
  String _selectedCategory = 'All';

  List<Technique> get _filtered {
    if (_selectedCategory == 'All') return kTechniquesSeed;
    return kTechniquesSeed
        .where((t) => t.category == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Technique Library')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category filter chips
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: kTechniqueCategories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = kTechniqueCategories[index];
                final selected = _selectedCategory == cat;
                return FilterChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                  selectedColor: AppTheme.primary,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppTheme.textPrimary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                );
              },
            ),
          ),

          // Technique list
          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No techniques in this category.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final technique = _filtered[index];
                      return TechniqueCard(
                        technique: technique,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                TechniqueDetailScreen(technique: technique),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
