import 'package:flutter/foundation.dart';
import '../models/match_log.dart';
import '../services/database_service.dart';

class MatchLogProvider extends ChangeNotifier {
  List<MatchLog> _matchLogs = [];
  bool _loaded = false;

  /// Newest first, mirroring the DB's date-desc order.
  List<MatchLog> get matchLogs => _matchLogs;

  Future<void> loadMatchLogs() async {
    if (_loaded) return;
    await refresh();
  }

  /// Reloads from the DB unconditionally (pull-to-refresh).
  Future<void> refresh() async {
    _matchLogs = await DatabaseService.getMatchLogs();
    _loaded = true;
    notifyListeners();
  }

  Future<void> addMatchLog(MatchLog log) async {
    await DatabaseService.insertMatchLog(log);
    _matchLogs = [log, ..._matchLogs]..sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  Future<void> updateMatchLog(MatchLog log) async {
    await DatabaseService.updateMatchLog(log);
    _matchLogs = [for (final l in _matchLogs) l.id == log.id ? log : l]
      ..sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  Future<void> deleteMatchLog(String id) async {
    await DatabaseService.deleteMatchLog(id);
    _matchLogs = _matchLogs.where((l) => l.id != id).toList();
    notifyListeners();
  }

  // ── Computed properties ────────────────────────────────────────────────

  int get wins => _matchLogs.where((l) => l.isWin).length;

  int get losses => _matchLogs.where((l) => !l.isWin).length;

  MatchLog? get latestLog => _matchLogs.isEmpty ? null : _matchLogs.first;
}
