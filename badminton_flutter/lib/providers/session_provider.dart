import 'package:flutter/foundation.dart';
import '../models/session.dart';
import '../services/database_service.dart';
import '../services/photo_store.dart';
import '../utils/streak.dart' as streak_util;

class SessionProvider extends ChangeNotifier {
  List<TrainingSession> _sessions = [];
  List<String> _customTags = [];
  bool _loaded = false;

  List<TrainingSession> get sessions => _sessions;

  List<String> get customTags => _customTags;

  /// Built-in drills first, then the user's own tags.
  List<String> get allDrillTypes => [...kDrillTypes, ..._customTags];

  Future<void> loadSessions() async {
    if (_loaded) return;
    await refresh();
  }

  /// Reloads from the DB unconditionally (pull-to-refresh).
  Future<void> refresh() async {
    _sessions = await DatabaseService.getSessions();
    _customTags = await DatabaseService.getCustomTags();
    _loaded = true;
    notifyListeners();
  }

  Future<void> addCustomTag(String name) async {
    final tag = name.trim();
    if (tag.isEmpty || kDrillTypes.contains(tag) || _customTags.contains(tag)) {
      return;
    }
    await DatabaseService.insertCustomTag(tag);
    _customTags = [..._customTags, tag];
    notifyListeners();
  }

  Future<void> deleteCustomTag(String name) async {
    await DatabaseService.deleteCustomTag(name);
    _customTags = _customTags.where((t) => t != name).toList();
    notifyListeners();
  }

  Future<void> addSession(TrainingSession session) async {
    await DatabaseService.insertSession(session);
    _sessions = [session, ..._sessions];
    notifyListeners();
  }

  Future<void> updateSession(TrainingSession session) async {
    await DatabaseService.updateSession(session);
    _sessions = [for (final s in _sessions) s.id == session.id ? session : s]
      ..sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  Future<void> deleteSession(String id) async {
    final photoPath = _sessions
        .where((s) => s.id == id)
        .map((s) => s.photoPath)
        .firstOrNull;
    await DatabaseService.deleteSession(id);
    if (photoPath != null && !kIsWeb) {
      await PhotoStore.instance.deletePhoto(photoPath);
    }
    _sessions.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  // ── Computed properties ────────────────────────────────────────────────

  int get currentStreak =>
      streak_util.currentStreak(_sessions.map((s) => s.date), DateTime.now());

  int get bestStreak => streak_util.bestStreak(_sessions.map((s) => s.date));

  int get sessionsThisWeek {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDay = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );
    return _sessions.where((s) => !s.date.isBefore(weekStartDay)).length;
  }

  int get sessionsThisMonth {
    final now = DateTime.now();
    return _sessions
        .where((s) => s.date.year == now.year && s.date.month == now.month)
        .length;
  }

  TrainingSession? get latestSession =>
      _sessions.isEmpty ? null : _sessions.first;

  /// Returns a map of week-start date → session count, for the last [weeks] weeks.
  Map<DateTime, int> sessionsPerWeek({int weeks = 8, DateTime? now}) {
    final effectiveNow = now ?? DateTime.now();
    final result = <DateTime, int>{};
    for (int i = weeks - 1; i >= 0; i--) {
      final weekStart = DateTime(
        effectiveNow.year,
        effectiveNow.month,
        effectiveNow.day,
      ).subtract(Duration(days: effectiveNow.weekday - 1 + 7 * i));
      final weekEnd = weekStart.add(const Duration(days: 7));
      final count = _sessions
          .where((s) => !s.date.isBefore(weekStart) && s.date.isBefore(weekEnd))
          .length;
      result[weekStart] = count;
    }
    return result;
  }

  /// Weekly average of [value] over the last [weeks] weeks; sessions where
  /// [value] is null are excluded, and empty weeks report 0.
  Map<DateTime, double> _avgPerWeek(
    int weeks,
    DateTime? now,
    int? Function(TrainingSession) value,
  ) {
    final effectiveNow = now ?? DateTime.now();
    final result = <DateTime, double>{};
    for (int i = weeks - 1; i >= 0; i--) {
      final weekStart = DateTime(
        effectiveNow.year,
        effectiveNow.month,
        effectiveNow.day,
      ).subtract(Duration(days: effectiveNow.weekday - 1 + 7 * i));
      final weekEnd = weekStart.add(const Duration(days: 7));
      final scores = _sessions
          .where((s) => !s.date.isBefore(weekStart) && s.date.isBefore(weekEnd))
          .map(value)
          .whereType<int>()
          .toList();
      result[weekStart] = scores.isEmpty
          ? 0
          : scores.reduce((a, b) => a + b) / scores.length;
    }
    return result;
  }

  /// Returns average intensity per week for the last [weeks] weeks.
  /// Sessions logged since the goal redesign have no intensity; only legacy
  /// rated sessions count toward the average.
  Map<DateTime, double> avgIntensityPerWeek({int weeks = 8, DateTime? now}) =>
      _avgPerWeek(weeks, now, (s) => s.intensity);

  /// Returns average goal-achievement score per week for the last [weeks]
  /// weeks (drives the home-screen trend chart).
  Map<DateTime, double> avgGoalAchievementPerWeek({
    int weeks = 8,
    DateTime? now,
  }) => _avgPerWeek(weeks, now, (s) => s.goalAchievementScore);
}
