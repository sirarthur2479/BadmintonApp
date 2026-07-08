import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/player.dart';
import '../services/analysis_server_settings.dart';
import '../services/api_client.dart';

/// Connection state for the LAN analysis server (mobile-only feature).
///
/// Deliberately separate from the web-only [AuthProvider]: mobile stays
/// offline-first for its data, and this token only ever authorises video
/// uploads and job polling against the owner's home server.
class AnalysisServerProvider extends ChangeNotifier {
  final http.Client _http;

  String? _address;
  String? _token;
  String? _playerId;
  String? _playerName;

  AnalysisServerProvider({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  String? get address => _address;
  String? get token => _token;
  String? get playerId => _playerId;
  String? get playerName => _playerName;

  /// Ready to upload: server known, signed in, player chosen.
  bool get isReady => _address != null && _token != null && _playerId != null;

  ApiClient _api() => ApiClient(
        baseUrl: '$_address/api/v1',
        inner: _http,
        tokenProvider: () => _token,
      );

  Future<void> restore() async {
    final stored = await AnalysisServerSettings.load();
    _address = stored.address;
    _token = stored.token;
    _playerId = stored.playerId;
    _playerName = stored.playerName;
    notifyListeners();
  }

  /// Normalises and persists the server address:
  /// `192.168.1.50:8001/` -> `http://192.168.1.50:8001`.
  Future<void> configure(String rawAddress) async {
    var address = rawAddress.trim();
    if (!address.startsWith('http://') && !address.startsWith('https://')) {
      address = 'http://$address';
    }
    while (address.endsWith('/')) {
      address = address.substring(0, address.length - 1);
    }
    _address = address;
    await AnalysisServerSettings.save(address: address);
    notifyListeners();
  }

  /// Returns null on success, or a user-readable error message.
  Future<String?> login(String email, String password) async {
    if (_address == null) {
      return 'Enter the server address first';
    }
    try {
      final body = await _api().postJson(
        '/auth/login',
        {'email': email, 'password': password},
      );
      _token = body['access_token'] as String;
      await AnalysisServerSettings.save(token: _token);
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return 'Could not reach the server: $e';
    }
  }

  Future<List<Player>> loadPlayers() async {
    final body = await _api().getJson('/players') as List;
    return body
        .map((m) => Player.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<void> selectPlayer(String id, String name) async {
    _playerId = id;
    _playerName = name;
    await AnalysisServerSettings.save(playerId: id, playerName: name);
    notifyListeners();
  }

  Future<void> signOut() async {
    _address = null;
    _token = null;
    _playerId = null;
    _playerName = null;
    await AnalysisServerSettings.clear();
    notifyListeners();
  }
}
