import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:badminton_flutter/providers/analysis_server_provider.dart';

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

MockClient happyServer() => MockClient((request) async {
      if (request.url.path.endsWith('/auth/login')) {
        return http.Response(
          jsonEncode({'access_token': 'jwt-lan', 'token_type': 'bearer'}),
          200,
        );
      }
      if (request.url.path.endsWith('/players')) {
        expect(request.headers['authorization'], 'Bearer jwt-lan');
        return http.Response(jsonEncode(_players), 200);
      }
      return http.Response('{}', 404);
    });

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('configure', () {
    test('normalises bare host and trailing slash', () async {
      final provider = AnalysisServerProvider(httpClient: happyServer());

      await provider.configure('192.168.1.50:8001');
      expect(provider.address, 'http://192.168.1.50:8001');

      await provider.configure('http://192.168.1.50:8001/');
      expect(provider.address, 'http://192.168.1.50:8001');
    });

    test('persists the address', () async {
      final provider = AnalysisServerProvider(httpClient: happyServer());

      await provider.configure('192.168.1.50:8001');

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('analysis_server_address'),
        'http://192.168.1.50:8001',
      );
    });
  });

  group('login', () {
    test('stores jwt against the configured address and returns null',
        () async {
      final provider = AnalysisServerProvider(httpClient: happyServer());
      await provider.configure('192.168.1.50:8001');

      final error = await provider.login('parent@example.com', 'hunter22');

      expect(error, isNull);
      expect(provider.token, 'jwt-lan');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('analysis_token'), 'jwt-lan');
    });

    test('surfaces backend detail message on 401', () async {
      final provider = AnalysisServerProvider(
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'detail': 'invalid email or password'}),
            401,
          ),
        ),
      );
      await provider.configure('192.168.1.50:8001');

      final error = await provider.login('parent@example.com', 'wrong');

      expect(error, contains('invalid'));
      expect(provider.token, isNull);
    });

    test('without an address returns a readable error', () async {
      final provider = AnalysisServerProvider(httpClient: happyServer());

      final error = await provider.login('parent@example.com', 'hunter22');

      expect(error, contains('address'));
    });
  });

  group('players', () {
    test('loadPlayers returns account players', () async {
      final provider = AnalysisServerProvider(httpClient: happyServer());
      await provider.configure('192.168.1.50:8001');
      await provider.login('parent@example.com', 'hunter22');

      final players = await provider.loadPlayers();

      expect(players.map((p) => p.name), ['Kid One', 'Kid Two']);
    });

    test('selectPlayer persists the choice', () async {
      final provider = AnalysisServerProvider(httpClient: happyServer());

      await provider.selectPlayer('pl-2', 'Kid Two');

      expect(provider.playerId, 'pl-2');
      expect(provider.playerName, 'Kid Two');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('analysis_player_id'), 'pl-2');
    });
  });

  group('isReady', () {
    test('only when address token and player are all set', () async {
      final provider = AnalysisServerProvider(httpClient: happyServer());
      expect(provider.isReady, isFalse);

      await provider.configure('192.168.1.50:8001');
      expect(provider.isReady, isFalse);

      await provider.login('parent@example.com', 'hunter22');
      expect(provider.isReady, isFalse);

      await provider.selectPlayer('pl-1', 'Kid One');
      expect(provider.isReady, isTrue);
    });

    test('restore rebuilds a ready provider from prefs', () async {
      SharedPreferences.setMockInitialValues({
        'analysis_server_address': 'http://192.168.1.50:8001',
        'analysis_token': 'jwt-lan',
        'analysis_player_id': 'pl-1',
        'analysis_player_name': 'Kid One',
      });
      final provider = AnalysisServerProvider(httpClient: happyServer());

      await provider.restore();

      expect(provider.isReady, isTrue);
      expect(provider.address, 'http://192.168.1.50:8001');
      expect(provider.playerName, 'Kid One');
    });

    test('signOut clears everything', () async {
      final provider = AnalysisServerProvider(httpClient: happyServer());
      await provider.configure('192.168.1.50:8001');
      await provider.login('parent@example.com', 'hunter22');
      await provider.selectPlayer('pl-1', 'Kid One');

      await provider.signOut();

      expect(provider.isReady, isFalse);
      expect(provider.token, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('analysis_token'), isNull);
    });
  });
}
