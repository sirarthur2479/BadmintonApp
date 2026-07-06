import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:badminton_flutter/services/api_client.dart';

void main() {
  test('getJson parses a json response', () async {
    final client = ApiClient(
      baseUrl: 'http://api.test/api/v1',
      inner: MockClient((request) async {
        expect(request.url.toString(), 'http://api.test/api/v1/players');
        return http.Response(jsonEncode([{'id': 'p1'}]), 200);
      }),
    );

    final body = await client.getJson('/players');

    expect(body, [{'id': 'p1'}]);
  });

  test('attaches bearer header when a token provider is set', () async {
    String? seenAuth;
    final client = ApiClient(
      baseUrl: 'http://api.test/api/v1',
      tokenProvider: () => 'jwt-123',
      inner: MockClient((request) async {
        seenAuth = request.headers['authorization'];
        return http.Response('{}', 200);
      }),
    );

    await client.getJson('/me');

    expect(seenAuth, 'Bearer jwt-123');
  });

  test('sends no auth header without a token', () async {
    String? seenAuth = 'sentinel';
    final client = ApiClient(
      baseUrl: 'http://api.test/api/v1',
      inner: MockClient((request) async {
        seenAuth = request.headers['authorization'];
        return http.Response('{}', 200);
      }),
    );

    await client.getJson('/me');

    expect(seenAuth, isNull);
  });

  test('postJson sends a json body with content-type', () async {
    Map<String, dynamic>? seenBody;
    final client = ApiClient(
      baseUrl: 'http://api.test/api/v1',
      inner: MockClient((request) async {
        expect(request.headers['content-type'], startsWith('application/json'));
        seenBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(request.body, 201);
      }),
    );

    await client.postJson('/auth/register', {'email': 'a@b.c', 'password': 'x'});

    expect(seenBody, {'email': 'a@b.c', 'password': 'x'});
  });

  test('non-2xx throws ApiException with status and detail', () async {
    final client = ApiClient(
      baseUrl: 'http://api.test/api/v1',
      inner: MockClient(
        (_) async =>
            http.Response(jsonEncode({'detail': 'email already registered'}), 409),
      ),
    );

    expect(
      () => client.postJson('/auth/register', {'email': 'a', 'password': 'b'}),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.message, 'message', contains('already registered')),
      ),
    );
  });

  test('delete returns normally on 204', () async {
    final client = ApiClient(
      baseUrl: 'http://api.test/api/v1',
      inner: MockClient((_) async => http.Response('', 204)),
    );

    await client.delete('/players/p1');
  });
}
