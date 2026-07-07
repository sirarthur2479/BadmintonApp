import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:badminton_flutter/providers/auth_provider.dart';
import 'package:badminton_flutter/services/api_client.dart';

ApiClient clientReturning(MockClientHandler handler) =>
    ApiClient(baseUrl: 'http://api.test/api/v1', inner: MockClient(handler));

ApiClient happyAuthClient() => clientReturning((request) async {
      if (request.url.path.endsWith('/auth/register')) {
        final body = jsonDecode(request.body);
        return http.Response(
          jsonEncode({'id': 'acc-1', 'email': body['email']}),
          201,
        );
      }
      if (request.url.path.endsWith('/auth/login')) {
        return http.Response(
          jsonEncode({'access_token': 'jwt-abc', 'token_type': 'bearer'}),
          200,
        );
      }
      return http.Response('{}', 200);
    });

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('login stores token and sets isLoggedIn', () async {
    final auth = AuthProvider(client: happyAuthClient());

    final error = await auth.login('parent@example.com', 'hunter22');

    expect(error, isNull);
    expect(auth.isLoggedIn, isTrue);
    expect(auth.token, 'jwt-abc');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), 'jwt-abc');
  });

  test('login with 401 exposes error and stays logged out', () async {
    final auth = AuthProvider(
      client: clientReturning(
        (_) async => http.Response(
          jsonEncode({'detail': 'invalid email or password'}),
          401,
        ),
      ),
    );

    final error = await auth.login('parent@example.com', 'wrong');

    expect(error, contains('invalid'));
    expect(auth.isLoggedIn, isFalse);
    expect(auth.token, isNull);
  });

  test('register auto-logs-in on success', () async {
    final auth = AuthProvider(client: happyAuthClient());

    final error = await auth.register('parent@example.com', 'hunter22');

    expect(error, isNull);
    expect(auth.isLoggedIn, isTrue);
  });

  test('register surfaces duplicate-email error', () async {
    final auth = AuthProvider(
      client: clientReturning(
        (_) async => http.Response(
          jsonEncode({'detail': 'email already registered'}),
          409,
        ),
      ),
    );

    final error = await auth.register('parent@example.com', 'hunter22');

    expect(error, contains('already registered'));
    expect(auth.isLoggedIn, isFalse);
  });

  test('logout clears token from prefs', () async {
    final auth = AuthProvider(client: happyAuthClient());
    await auth.login('parent@example.com', 'hunter22');

    await auth.logout();

    expect(auth.isLoggedIn, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), isNull);
  });

  test('restore picks up a persisted token', () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'jwt-persisted'});
    final auth = AuthProvider(client: happyAuthClient());

    await auth.restore();

    expect(auth.isLoggedIn, isTrue);
    expect(auth.token, 'jwt-persisted');
  });

  test('notifies listeners on login and logout', () async {
    final auth = AuthProvider(client: happyAuthClient());
    var notifications = 0;
    auth.addListener(() => notifications++);

    await auth.login('parent@example.com', 'hunter22');
    await auth.logout();

    expect(notifications, greaterThanOrEqualTo(2));
  });
}
