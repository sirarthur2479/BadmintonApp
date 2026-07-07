import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/player.dart';
import '../services/api_client.dart';

/// The account's players and the currently active one (web flow).
class PlayerProvider extends ChangeNotifier {
  static const _activeKey = 'active_player_id';

  final ApiClient _client;
  List<Player> _players = [];
  Player? _activePlayer;

  PlayerProvider({ApiClient? client}) : _client = client ?? ApiClient();

  List<Player> get players => _players;

  Player? get activePlayer => _activePlayer;

  Future<void> loadPlayers() async {
    final body = await _client.getJson('/players') as List;
    _players = [
      for (final item in body) Player.fromMap(item as Map<String, dynamic>),
    ];
    final prefs = await SharedPreferences.getInstance();
    final rememberedId = prefs.getString(_activeKey);
    _activePlayer = _players.where((p) => p.id == rememberedId).firstOrNull;
    // A one-player account never needs the select screen.
    if (_activePlayer == null && _players.length == 1) {
      await switchPlayer(_players.single.id);
      return;
    }
    notifyListeners();
  }

  Future<void> switchPlayer(String id) async {
    _activePlayer = _players.firstWhere((p) => p.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, id);
    notifyListeners();
  }

  Future<Player> addPlayer({required String name}) async {
    final player = Player(id: const Uuid().v4(), name: name);
    await _client.postJson('/players', player.toMap());
    _players = [..._players, player];
    notifyListeners();
    return player;
  }

  /// Back to the select screen without logging out.
  Future<void> clearActivePlayer() async {
    _activePlayer = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeKey);
    notifyListeners();
  }

  /// Logout: forget everything.
  Future<void> clear() async {
    _players = [];
    await clearActivePlayer();
  }
}
