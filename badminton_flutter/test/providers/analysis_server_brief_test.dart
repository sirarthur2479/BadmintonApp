import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:badminton_flutter/providers/analysis_server_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<AnalysisServerProvider> signedIn(MockClient client) async {
    final provider = AnalysisServerProvider(httpClient: client);
    await provider.configure('192.168.1.50:8001');
    await provider.login('parent@home.lan', 'pw');
    return provider;
  }

  MockClient mock(
    Future<http.Response> Function(http.Request) onBrief,
  ) => MockClient((request) async {
    if (request.url.path.endsWith('/auth/login')) {
      return http.Response(jsonEncode({'access_token': 'jwt-1'}), 200);
    }
    if (request.url.path.endsWith('/coach/opponent-brief')) {
      return onBrief(request);
    }
    return http.Response('{"detail": "no route"}', 404);
  });

  test('requests the brief over the LAN client with the stored token', () async {
    late http.Request seen;
    final provider = await signedIn(
      mock((request) async {
        seen = request;
        return http.Response(jsonEncode({'markdown': '# Brief'}), 200);
      }),
    );

    final markdown = await provider.requestOpponentBrief('Ken T.', ['fact 1']);

    expect(markdown, '# Brief');
    expect(seen.url.toString(),
        'http://192.168.1.50:8001/api/v1/coach/opponent-brief');
    expect(seen.headers['Authorization'], 'Bearer jwt-1');
    expect(jsonDecode(seen.body)['opponent'], 'Ken T.');
  });

  test('throws when no server is configured', () async {
    final provider = AnalysisServerProvider(httpClient: mock((r) async {
      return http.Response('{}', 200);
    }));

    expect(
      () => provider.requestOpponentBrief('Ken T.', ['fact']),
      throwsA(isA<StateError>()),
    );
  });
}
