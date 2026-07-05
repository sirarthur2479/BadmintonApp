import 'package:flutter/foundation.dart';
import '../models/session.dart';
import '../services/database_service.dart';

class SessionProvider extends ChangeNotifier {
  List<TrainingSession> _sessions = [];
  bool _loaded = false;

  List<TrainingSession> get sessions => _sessions;

  Future<void> loadSessions() async {
    if (_loaded) return;
    await refresh();
  }

  /// Reloads from the DB unconditionally (pull-to-refresh).
  Future<void> refresh() async {
    _sessions = await DatabaseService.getSessions();
    _loaded = true;
    notifyListeners();
  }

  Future<void> addSession(TrainingSession session) async {
    await DatabaseService.insertSession(session);
    _sessions = [session, ..._sessions];
    notifyListeners();
  }

  Future<void> deleteSession(String id) async {
    await DatabaseService.deleteSession(id);
    _sessions.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  // ── Computed properties ────────────────────────────────────────────────

  int get currentStreak {
    if (_sessions.isEmpty) return 0;
    final sorted = [..._sessions]..sort((a, b) => b.date.compareTo(a.date));
    final today = DateTime.now();
    int streak = 0;
    DateTime? lastDate;

    for (final session in sorted) {
      final sessionDay =
          DateTime(session.date.year, session.date.month, session.date.day);
      if (lastDate == null) {
        final todayDay = DateTime(today.year, today.month, today.day);
        final diff = todayDay.difference(sessionDay).inDays;
        if (diff > 1) break; // No session today or yesterday — no streak
        streak = 1;
        lastDate = sessionDay;
      } else {
        final diff = lastDate.difference(sessionDay).inDays;
        if (diff == 1) {
          streak++;
          lastDate = sessionDay;
        } else if (diff == 0) {
          // Same day — multiple sessions, don't increment
          continue;
        } else {
          break;
        }
      }
    }
    return streak;
  }

  int get sessionsThisWeek {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDay =
        DateTime(weekStart.year, weekStart.month, weekStart.day);
    return _sessions
        .where((s) => !s.date.isBefore(weekStartDay))
        .length;
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
  Map<DateTime, int> sessionsPerWeek({int weeks = 8}) {
    final now = DateTime.now();
    final result = <DateTime, int>{};
    for (int i = weeks - 1; i >= 0; i--) {
      final weekStart = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1 + 7 * i));
      final weekEnd = weekStart.add(const Duration(days: 7));
      final count = _sessions
          .where((s) =>
              !s.date.isBefore(weekStart) && s.date.isBefore(weekEnd))
          .length;
      result[weekStart] = count;
    }
    return result;
  }

  /// Returns average intensity per week for the last [weeks] weeks.
  Map<DateTime, double> avgIntensityPerWeek({int weeks = 8}) {
    final now = DateTime.now();
    final result = <DateTime, double>{};
    for (int i = weeks - 1; i >= 0; i--) {
      final weekStart = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1 + 7 * i));
      final weekEnd = weekStart.add(const Duration(days: 7));
      final week = _sessions
          .where((s) =>
              !s.date.isBefore(weekStart) && s.date.isBefore(weekEnd))
          .toList();
      if (week.isEmpty) {
        result[weekStart] = 0;
      } else {
        final avg =
            week.map((s) => s.intensity).reduce((a, b) => a + b) / week.length;
        result[weekStart] = avg;
      }
    }
    return result;
  }
}
