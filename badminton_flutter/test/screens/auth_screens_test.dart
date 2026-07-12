import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:badminton_flutter/app.dart';
import 'package:badminton_flutter/providers/auth_provider.dart';
import 'package:badminton_flutter/providers/match_log_provider.dart';
import 'package:badminton_flutter/providers/profile_provider.dart';
import 'package:badminton_flutter/providers/session_provider.dart';
import 'package:badminton_flutter/providers/tournament_provider.dart';
import 'package:badminton_flutter/screens/auth/login_screen.dart';
import 'package:badminton_flutter/screens/auth/register_screen.dart';
import 'package:badminton_flutter/services/api_client.dart';
import 'package:badminton_flutter/services/database_service.dart';

ApiClient authClient({bool succeed = true}) => ApiClient(
      baseUrl: 'http://api.test/api/v1',
      inner: MockClient((request) async {
        if (!succeed) {
          return http.Response(
            jsonEncode({'detail': 'invalid email or password'}),
            401,
          );
        }
        if (request.url.path.endsWith('/auth/register')) {
          return http.Response(jsonEncode({'id': 'a1', 'email': 'e'}), 201);
        }
        return http.Response(
          jsonEncode({'access_token': 'jwt-abc', 'token_type': 'bearer'}),
          200,
        );
      }),
    );

Widget app(AuthProvider auth, Widget home) => ChangeNotifierProvider.value(
      value: auth,
      child: MaterialApp(home: home),
    );

Future<void> submit(WidgetTester tester) async {
  await tester.enterText(
      find.byKey(const ValueKey('emailField')), 'parent@example.com');
  await tester.enterText(
      find.byKey(const ValueKey('passwordField')), 'hunter22');
  await tester.tap(find.byKey(const ValueKey('submitButton')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('login screen logs in on submit', (tester) async {
    final auth = AuthProvider(client: authClient());

    await tester.pumpWidget(app(auth, const LoginScreen()));
    await submit(tester);

    expect(auth.isLoggedIn, isTrue);
  });

  testWidgets('login screen shows inline error on failure', (tester) async {
    final auth = AuthProvider(client: authClient(succeed: false));

    await tester.pumpWidget(app(auth, const LoginScreen()));
    await submit(tester);

    expect(find.textContaining('invalid'), findsOneWidget);
    expect(auth.isLoggedIn, isFalse);
  });

  testWidgets('login links to register and back', (tester) async {
    final auth = AuthProvider(client: authClient());

    await tester.pumpWidget(app(auth, const LoginScreen()));
    await tester.tap(find.byKey(const ValueKey('goToRegister')));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('goToLogin')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('register screen registers and logs in', (tester) async {
    final auth = AuthProvider(client: authClient());

    await tester.pumpWidget(app(auth, const RegisterScreen()));
    await submit(tester);

    expect(auth.isLoggedIn, isTrue);
  });

  group('auth gate', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      DatabaseService.dbName = 'auth_gate_test.db';
    });

    Widget gated(AuthProvider auth, {required bool web}) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider(create: (_) => SessionProvider()),
            ChangeNotifierProvider(create: (_) => TournamentProvider()),
            ChangeNotifierProvider(create: (_) => ProfileProvider()),
            ChangeNotifierProvider(create: (_) => MatchLogProvider()),
          ],
          child: MaterialApp(home: AuthGate(webOverride: web)),
        );

    testWidgets('web + logged out shows login screen', (tester) async {
      final auth = AuthProvider(client: authClient());

      await tester.pumpWidget(gated(auth, web: true));

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(MainShell), findsNothing);
    });

    testWidgets('non-web bypasses auth entirely', (tester) async {
      await tester.runAsync(() => DatabaseService.resetForTests());
      final auth = AuthProvider(client: authClient());

      await tester.pumpWidget(gated(auth, web: false));
      await tester.pump();

      expect(find.byType(MainShell), findsOneWidget,
          reason: 'mobile must stay offline-first, no login');
    });
  });
}
