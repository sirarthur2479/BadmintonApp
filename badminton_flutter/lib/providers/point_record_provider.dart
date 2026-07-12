import 'package:flutter/foundation.dart';
import '../models/point_record.dart';
import '../services/database_service.dart';

/// Tagging state for one match log's point records (pool #10 phase 1).
/// Follows the MatchLogProvider conventions: load-once per log with an
/// unconditional [refresh], optimistic local list updates.
class PointRecordProvider extends ChangeNotifier {
  List<PointRecord> _points = [];
  String? _loadedLogId;

  /// Ordered by game, then indexInGame — the DB's order.
  List<PointRecord> get points => _points;

  /// Loads the given log's points; a repeat call for the same log is a
  /// no-op guard, not a reload.
  Future<void> loadFor(String matchLogId) async {
    if (_loadedLogId == matchLogId) return;
    _loadedLogId = matchLogId;
    await refresh();
  }

  /// Reloads the current log's points from the DB unconditionally.
  Future<void> refresh() async {
    final logId = _loadedLogId;
    if (logId == null) return;
    _points = await DatabaseService.getPointRecords(logId);
    notifyListeners();
  }

  Future<void> addPoint(PointRecord point) async {
    await DatabaseService.insertPointRecord(point);
    _points = [..._points, point]..sort(
      (a, b) => a.game != b.game
          ? a.game.compareTo(b.game)
          : a.indexInGame.compareTo(b.indexInGame),
    );
    notifyListeners();
  }

  /// Removes the newest tagged point (highest game, then index).
  Future<void> undoLast() async {
    if (_points.isEmpty) return;
    final last = _points.last;
    await DatabaseService.deletePointRecord(last.matchLogId, last.id);
    _points = [..._points]..removeLast();
    notifyListeners();
  }

  /// The retag path: replaces the log's entire point set.
  Future<void> clearAndReplace(
    String matchLogId,
    List<PointRecord> points,
  ) async {
    await DatabaseService.clearPointRecords(matchLogId);
    await DatabaseService.insertPointRecords(points);
    _loadedLogId = matchLogId;
    await refresh();
  }

  /// Every point record across all match logs — the profiling feed. Does
  /// not disturb the currently loaded tagging view.
  Future<List<PointRecord>> allPoints() => DatabaseService.getAllPointRecords();
}
