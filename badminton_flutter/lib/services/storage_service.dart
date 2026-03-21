import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/player_profile.dart';

class StorageService {
  static const _profileKey = 'player_profile';

  static Future<PlayerProfile> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_profileKey);
    if (jsonStr == null) return const PlayerProfile();
    try {
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      return PlayerProfile.fromJson(map);
    } catch (_) {
      return const PlayerProfile();
    }
  }

  static Future<void> saveProfile(PlayerProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, json.encode(profile.toJson()));
  }
}
