class TechniqueLevel {
  final String description;
  final List<String> keyTips;
  final List<String> commonMistakes;

  const TechniqueLevel({
    required this.description,
    required this.keyTips,
    required this.commonMistakes,
  });
}

class Technique {
  final String id;
  final String name;
  final String category; // footwork | stroke | serve | tactics
  final String difficulty; // beginner | intermediate | advanced
  final String? animationAsset; // future: path to Lottie/Rive file
  final List<String> relatedDrills;
  final Map<String, TechniqueLevel> contentByLevel; // keys: beginner, intermediate, advanced

  const Technique({
    required this.id,
    required this.name,
    required this.category,
    required this.difficulty,
    this.animationAsset,
    required this.relatedDrills,
    required this.contentByLevel,
  });

  TechniqueLevel get beginnerContent =>
      contentByLevel['beginner'] ?? contentByLevel.values.first;

  TechniqueLevel get intermediateContent =>
      contentByLevel['intermediate'] ?? contentByLevel.values.first;

  TechniqueLevel get advancedContent =>
      contentByLevel['advanced'] ?? contentByLevel.values.first;

  TechniqueLevel contentFor(String level) =>
      contentByLevel[level] ?? beginnerContent;
}

const List<String> kTechniqueCategories = [
  'All',
  'Footwork',
  'Stroke',
  'Serve',
  'Tactics',
];

const List<String> kTechniqueLevels = [
  'beginner',
  'intermediate',
  'advanced',
];
