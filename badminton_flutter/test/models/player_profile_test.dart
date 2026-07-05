import 'package:flutter_test/flutter_test.dart';

import 'package:badminton_flutter/models/player_profile.dart';

void main() {
  group('PlayerProfile toJson/fromJson', () {
    test('round-trips a fully-filled profile', () {
      const profile = PlayerProfile(
        name: 'Jamie Rivera',
        age: 12,
        club: 'Riverside Badminton Club',
        yearsPlaying: 4,
        photoPath: 'profile_photos/jamie.jpg',
        playingStyle: 'attacking',
        preferredGrip: 'backhand',
        shortTermGoal: 'Improve backhand clear',
        longTermGoal: 'Compete at nationals',
      );

      final restored = PlayerProfile.fromJson(profile.toJson());

      expect(restored.name, profile.name);
      expect(restored.age, profile.age);
      expect(restored.club, profile.club);
      expect(restored.yearsPlaying, profile.yearsPlaying);
      expect(restored.photoPath, profile.photoPath);
      expect(restored.playingStyle, profile.playingStyle);
      expect(restored.preferredGrip, profile.preferredGrip);
      expect(restored.shortTermGoal, profile.shortTermGoal);
      expect(restored.longTermGoal, profile.longTermGoal);
    });

    test('round-trips the default (empty) profile', () {
      const profile = PlayerProfile();

      final restored = PlayerProfile.fromJson(profile.toJson());

      expect(restored.name, '');
      expect(restored.age, isNull);
      expect(restored.club, '');
      expect(restored.yearsPlaying, isNull);
      expect(restored.photoPath, isNull);
      expect(restored.playingStyle, 'all-round');
      expect(restored.preferredGrip, 'forehand');
      expect(restored.shortTermGoal, '');
      expect(restored.longTermGoal, '');
    });

    test('fromJson falls back to defaults for missing keys', () {
      final restored = PlayerProfile.fromJson(const {});

      expect(restored.name, '');
      expect(restored.age, isNull);
      expect(restored.club, '');
      expect(restored.yearsPlaying, isNull);
      expect(restored.photoPath, isNull);
      expect(restored.playingStyle, 'all-round');
      expect(restored.preferredGrip, 'forehand');
      expect(restored.shortTermGoal, '');
      expect(restored.longTermGoal, '');
    });
  });
}
