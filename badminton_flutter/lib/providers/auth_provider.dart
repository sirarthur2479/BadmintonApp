import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';

/// Web-only authentication state. Mobile never constructs the login flow —
/// the auth gate is bypassed off-web and the token is only ever stored on
/// the web (localStorage via shared_preferences).
class AuthProvider extends ChangeNotifier {
  static const _tokenKey = 'auth_token';

  final ApiClient _client;
  String? _token;

  AuthProvider({ApiClient? client}) : _client = client ?? ApiClient();

  bool get isLoggedIn => _token != null;

  String? get token => _token;

  /// Restores a persisted session at startup.
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    if (_token != null) notifyListeners();
  }

  /// Returns null on success, or a user-readable error message.
  Future<String?> login(String email, String password) async {
    try {
      final body = await _client.postJson(
        '/auth/login',
        {'email': email, 'password': password},
      );
      _token = body['access_token'] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, _token!);
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Registers, then logs straight in. Returns null on success.
  Future<String?> register(String email, String password) async {
    try {
      await _client.postJson(
        '/auth/register',
        {'email': email, 'password': password},
      );
    } on ApiException catch (e) {
      return e.message;
    }
    return login(email, password);
  }

  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    notifyListeners();
  }
}
