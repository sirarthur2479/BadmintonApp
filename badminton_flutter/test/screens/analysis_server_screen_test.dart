import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:badminton_flutter/providers/analysis_server_provider.dart';
import 'package:badminton_flutter/providers/profile_provider.dart';
import 'package:badminton_flutter/screens/profile/profile_screen.dart';
import 'package:badminton_flutter/screens/settings/analysis_server_screen.dart';

const _players = [
  {
    'id': 'pl-1',
    'name': 'Kid One',
    'age': 12,
    'club': '',
    'playingStyle': '',
    'preferredGrip': '',
    'shortTermGoal': '',
    'longTermGoal': '',
    'photoPath': null,
  },
  {
    'id': 'pl-2',
    'name': 'Kid Two',
    'age': 10,
    'club': '',
    'playingStyle': '',
    'preferredGrip': '',
    'shortTermGoal': '',
    'longTermGoal': '',
    'photoPath': null,
  },
];

MockClient analysisServer() => MockClient((request) async {
      if (request.method == 'OPTIONS' &&
          request.url.path.endsWith('/uploads')) {
        return http.Response('', 204, headers: {'tus-resumable': '1.0.0'});
      }
      if (request.url.path.endsWith('/auth/login')) {
        return http.Response(
          jsonEncode({'access_token': 'jwt-lan', 'token_type': 'bearer'}),
          200,
        );
      }
      if (request.url.path.endsWith('/players')) {
        return http.Response(jsonEncode(_players), 200);
      }
      return http.Response('{}', 404);
    });

Widget _screen(AnalysisServerProvider provider) =>
    ChangeNotifierProvider.value(
      value: provider,
      child: const MaterialApp(home: AnalysisServerScreen()),
    );

Future<void> _pumpTall(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(widget);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('full flow: address, sign in, pick player, test connection',
      (tester) async {
    final provider = AnalysisServerProvider(httpClient: analysisServer());
    await _pumpTall(tester, _screen(provider));

    await tester.enterText(
        find.byKey(const ValueKey('addressField')), '192.168.1.50:8001');
    await tester.enterText(
        find.byKey(const ValueKey('emailField')), 'parent@example.com');
    await tester.enterText(
        find.byKey(const ValueKey('passwordField')), 'hunter22');
    await tester.tap(find.byKey(const ValueKey('signInButton')),
        warnIfMissed: false);
    await tester.pumpAndSettle();

    // Signed in: player choices load.
    expect(find.text('Kid One', skipOffstage: false), findsOneWidget);
    await tester.tap(find.text('Kid Two', skipOffstage: false),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(provider.playerId, 'pl-2');

    await tester.tap(find.byKey(const ValueKey('testConnectionButton')),
        warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.textContaining('Connected', skipOffstage: false),
        findsOneWidget);
    expect(provider.isReady, isTrue);
  });

  testWidgets('failed sign-in shows the backend message', (tester) async {
    final provider = AnalysisServerProvider(
      httpClient: MockClient(
        (_) async => http.Response(
            jsonEncode({'detail': 'invalid email or password'}), 401),
      ),
    );
    await _pumpTall(tester, _screen(provider));

    await tester.enterText(
        find.byKey(const ValueKey('addressField')), '192.168.1.50:8001');
    await tester.enterText(
        find.byKey(const ValueKey('emailField')), 'parent@example.com');
    await tester.enterText(
        find.byKey(const ValueKey('passwordField')), 'nope');
    await tester.tap(find.byKey(const ValueKey('signInButton')),
        warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.textContaining('invalid', skipOffstage: false),
        findsOneWidget);
    expect(provider.isReady, isFalse);
  });

  testWidgets('signed-in screen offers sign out', (tester) async {
    SharedPreferences.setMockInitialValues({
      'analysis_server_address': 'http://192.168.1.50:8001',
      'analysis_token': 'jwt-lan',
      'analysis_player_id': 'pl-1',
      'analysis_player_name': 'Kid One',
    });
    final provider = AnalysisServerProvider(httpClient: analysisServer());
    await provider.restore();
    await _pumpTall(tester, _screen(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('signOutButton')),
        warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(provider.isReady, isFalse);
  });

  group('profile entry point', () {
    Widget profileApp({required bool webOverride}) => MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ProfileProvider()),
            ChangeNotifierProvider(
              create: (_) =>
                  AnalysisServerProvider(httpClient: analysisServer()),
            ),
          ],
          child: MaterialApp(home: ProfileScreen(webOverride: webOverride)),
        );

    testWidgets('visible on mobile', (tester) async {
      await _pumpTall(tester, profileApp(webOverride: false));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('analysisServerButton')),
        findsOneWidget,
      );
    });

    testWidgets('hidden on web', (tester) async {
      await _pumpTall(tester, profileApp(webOverride: true));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('analysisServerButton')),
        findsNothing,
      );
    });
  });
}
