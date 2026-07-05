import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:badminton_flutter/models/player_profile.dart';
import 'package:badminton_flutter/providers/profile_provider.dart';
import 'package:badminton_flutter/screens/profile/profile_screen.dart';

const _savedProfile = PlayerProfile(
  name: 'Test Player',
  age: 11,
  club: 'North Shore BC',
  playingStyle: 'attacking',
  preferredGrip: 'forehand',
  shortTermGoal: 'Sharper net kills',
  longTermGoal: 'Regional top 8',
);

Widget _app(ProfileProvider provider) => ChangeNotifierProvider.value(
      value: provider,
      child: const MaterialApp(home: ProfileScreen()),
    );

void main() {
  testWidgets('form fields populate when profile loads after first build',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'player_profile': json.encode(_savedProfile.toJson())});
    final provider = ProfileProvider();

    // Screen mounts BEFORE the profile has loaded (mirrors app startup,
    // where all tabs build eagerly in an IndexedStack).
    await tester.pumpWidget(_app(provider));
    expect(find.widgetWithText(TextField, 'Test Player'), findsNothing);

    await provider.loadProfile();
    await tester.pumpAndSettle();

    expect(find.text('Test Player'), findsOneWidget,
        reason: 'name must appear once the async load completes');
    expect(find.text('North Shore BC'), findsOneWidget);
    expect(find.text('11'), findsOneWidget,
        reason: 'age must populate too (TextFormField initialValue trap)');
  });

  testWidgets('in-flight edits survive a provider notification while editing',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'player_profile': json.encode(_savedProfile.toJson())});
    final provider = ProfileProvider();
    await provider.loadProfile();

    await tester.pumpWidget(_app(provider));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Test Player'), 'Halfway Typed');

    // Something else notifies the provider mid-edit.
    await provider.saveProfile(_savedProfile.copyWith(club: 'Changed Club'));
    await tester.pumpAndSettle();

    expect(find.text('Halfway Typed'), findsOneWidget,
        reason: 'unsaved edits must not be clobbered while editing');
  });

  testWidgets('save writes the edited profile to the provider',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'player_profile': json.encode(_savedProfile.toJson())});
    final provider = ProfileProvider();
    await provider.loadProfile();

    await tester.pumpWidget(_app(provider));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Test Player'), 'Updated Kid');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(provider.profile.name, 'Updated Kid');
    expect(provider.profile.club, 'North Shore BC');
  });
}
