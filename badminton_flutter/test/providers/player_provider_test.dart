import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:badminton_flutter/providers/player_provider.dart';
import 'package:badminton_flutter/services/api_client.dart';

final _twoPlayers = [
  {'id': 'p1', 'name': 'Kid One'},
  {'id': 'p2', 'name': 'Kid Two'},
];

ApiClient playersClient({List<Map<String, dynamic>>? players}) {
  final store = List<Map<String, dynamic>>.from(players ?? _twoPlayers);
  return ApiClient(
    baseUrl: 'http://api.test/api/v1',
    inner: MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(jsonEncode(store), 200);
      }
      if (request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        store.add(body);
        return http.Response(request.body, 201);
      }
      return http.Response('{}', 200);
    }),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loadPlayers populates from api', () async {
    final provider = PlayerProvider(client: playersClient());

    await provider.loadPlayers();

    expect(provider.players.map((p) => p.name), ['Kid One', 'Kid Two']);
    expect(provider.activePlayer, isNull, reason: 'no auto-pick with 2 players');
  });

  test('single-player account auto-selects on load', () async {
    final provider = PlayerProvider(
      client: playersClient(players: [_twoPlayers.first]),
    );

    await provider.loadPlayers();

    expect(provider.activePlayer?.id, 'p1');
  });

  test('switchPlayer persists and restores active id across instances',
      () async {
    final provider = PlayerProvider(client: playersClient());
    await provider.loadPlayers();

    await provider.switchPlayer('p2');
    expect(provider.activePlayer?.id, 'p2');

    final fresh = PlayerProvider(client: playersClient());
    await fresh.loadPlayers();
    expect(fresh.activePlayer?.id, 'p2', reason: 'remembered across restarts');
  });

  test('addPlayer posts with generated uuid and appends', () async {
    final provider = PlayerProvider(client: playersClient(players: []));
    await provider.loadPlayers();

    await provider.addPlayer(name: 'New Kid');

    expect(provider.players, hasLength(1));
    expect(provider.players.single.name, 'New Kid');
    expect(provider.players.single.id, isNotEmpty);
  });

  test('clearActivePlayer keeps players but forgets selection', () async {
    final provider = PlayerProvider(client: playersClient());
    await provider.loadPlayers();
    await provider.switchPlayer('p1');

    await provider.clearActivePlayer();

    expect(provider.activePlayer, isNull);
    expect(provider.players, hasLength(2));
  });

  test('clear wipes players and active id (logout)', () async {
    final provider = PlayerProvider(client: playersClient());
    await provider.loadPlayers();
    await provider.switchPlayer('p1');

    await provider.clear();

    expect(provider.players, isEmpty);
    expect(provider.activePlayer, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('active_player_id'), isNull);
  });
}
