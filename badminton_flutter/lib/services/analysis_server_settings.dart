import 'package:shared_preferences/shared_preferences.dart';

/// The stored analysis-server connection (LAN address + JWT + which
/// server-side player uploads belong to). Mobile-only feature state, kept
/// separate from the web auth token on purpose.
class AnalysisServerConnection {
  final String? address;
  final String? token;
  final String? playerId;
  final String? playerName;

  const AnalysisServerConnection({
    this.address,
    this.token,
    this.playerId,
    this.playerName,
  });
}

class AnalysisServerSettings {
  static const _addressKey = 'analysis_server_address';
  static const _tokenKey = 'analysis_token';
  static const _playerIdKey = 'analysis_player_id';
  static const _playerNameKey = 'analysis_player_name';

  static Future<AnalysisServerConnection> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AnalysisServerConnection(
      address: prefs.getString(_addressKey),
      token: prefs.getString(_tokenKey),
      playerId: prefs.getString(_playerIdKey),
      playerName: prefs.getString(_playerNameKey),
    );
  }

  /// Persists only the fields provided; null leaves a field untouched.
  static Future<void> save({
    String? address,
    String? token,
    String? playerId,
    String? playerName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (address != null) await prefs.setString(_addressKey, address);
    if (token != null) await prefs.setString(_tokenKey, token);
    if (playerId != null) await prefs.setString(_playerIdKey, playerId);
    if (playerName != null) await prefs.setString(_playerNameKey, playerName);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_addressKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_playerIdKey);
    await prefs.remove(_playerNameKey);
  }
}
