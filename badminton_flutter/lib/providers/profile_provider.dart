import 'package:flutter/foundation.dart';
import '../models/player_profile.dart';
import '../services/storage_service.dart';

class ProfileProvider extends ChangeNotifier {
  PlayerProfile _profile = const PlayerProfile();
  bool _loaded = false;

  PlayerProfile get profile => _profile;

  Future<void> loadProfile() async {
    if (_loaded) return;
    _profile = await StorageService.loadProfile();
    _loaded = true;
    notifyListeners();
  }

  Future<void> saveProfile(PlayerProfile profile) async {
    _profile = profile;
    await StorageService.saveProfile(profile);
    notifyListeners();
  }
}
