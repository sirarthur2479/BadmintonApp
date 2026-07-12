import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:badminton_flutter/models/match_log.dart';
import 'package:badminton_flutter/models/reflection_data.dart';
import 'package:badminton_flutter/models/session.dart';
import 'package:badminton_flutter/models/tournament.dart';
import 'package:badminton_flutter/services/api_client.dart';
import 'package:badminton_flutter/services/api_service.dart';

final _session = TrainingSession(
  id: 's1',
  date: DateTime(2026, 7, 14),
  durationMinutes: 75,
  drills: const ['Multi-feed, front court', 'Net Play'],
  sessionGoal: 'Sharper net kills',
  goalAchievementScore: 4,
  playerRemarks: 'crisp',
  coachRemarks: 'watch recovery',
  reflectionAnswersJson: encodeReflectionAnswers([
    ReflectionAnswer(
      questionKey: kReflectionQuestions[0],
      answer: 'coach picked it',
    ),
  ]),
);

final _tournament = Tournament(
  id: 't1',
  name: 'Regional U13',
  date: DateTime(2026, 6, 1),
  location: 'Auckland',
  format: 'Knockout',
);

final _match = TournamentMatch(
  id: 'm1',
  tournamentId: 't1',
  opponent: 'A. Rival',
  scores: const ['21-15', '21-18'],
  isWin: true,
);

/// An in-memory fake of the backend data routes, echoing what was stored.
class FakeBackend {
  final sessions = <Map<String, dynamic>>[];
  final tournaments = <Map<String, dynamic>>[];
  final tags = <String>[];
  final matchLogs = <Map<String, dynamic>>[];
  final requests = <String>[];

  ApiClient client() => ApiClient(
        baseUrl: 'http://api.test/api/v1',
        inner: MockClient(_handle),
      );

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path.replaceFirst('/api/v1', '');
    requests.add('${request.method} $path');
    if (path.endsWith('/sessions') && request.method == 'GET') {
      return http.Response(jsonEncode(sessions), 200);
    }
    if (path.endsWith('/sessions') && request.method == 'POST') {
      sessions.add(jsonDecode(request.body));
      return http.Response(request.body, 201);
    }
    if (path.endsWith('/sessions/batch')) {
      sessions.addAll((jsonDecode(request.body) as List).cast());
      return http.Response('{}', 201);
    }
    if (path.endsWith('/sessions/any')) {
      return http.Response(jsonEncode({'any': sessions.isNotEmpty}), 200);
    }
    if (path.contains('/sessions/') && request.method == 'PUT') {
      final id = path.split('/').last;
      final idx = sessions.indexWhere((s) => s['id'] == id);
      sessions[idx] = jsonDecode(request.body);
      return http.Response(request.body, 200);
    }
    if (path.contains('/sessions/') && request.method == 'DELETE') {
      sessions.removeWhere((s) => s['id'] == path.split('/').last);
      return http.Response('', 204);
    }
    if (path.endsWith('/match-logs') && request.method == 'GET') {
      return http.Response(jsonEncode(matchLogs), 200);
    }
    if (path.endsWith('/match-logs') && request.method == 'POST') {
      matchLogs.add(jsonDecode(request.body));
      return http.Response(request.body, 201);
    }
    if (path.endsWith('/match-logs/batch')) {
      matchLogs.addAll((jsonDecode(request.body) as List).cast());
      return http.Response('{}', 201);
    }
    if (path.endsWith('/match-logs/any')) {
      return http.Response(jsonEncode({'any': matchLogs.isNotEmpty}), 200);
    }
    if (path.contains('/match-logs/') && request.method == 'PUT') {
      final id = path.split('/').last;
      final idx = matchLogs.indexWhere((l) => l['id'] == id);
      matchLogs[idx] = jsonDecode(request.body);
      return http.Response(request.body, 200);
    }
    if (path.contains('/match-logs/') && request.method == 'DELETE') {
      matchLogs.removeWhere((l) => l['id'] == path.split('/').last);
      return http.Response('', 204);
    }
    if (path.endsWith('/tournaments') && request.method == 'GET') {
      return http.Response(jsonEncode(tournaments), 200);
    }
    if (path.endsWith('/tournaments') && request.method == 'POST') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      tournaments.add({...body, 'matches': []});
      return http.Response(request.body, 201);
    }
    if (path.contains('/tournaments/') && path.endsWith('/matches')) {
      final tid = path.split('/')[4];
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      tournaments
          .firstWhere((t) => t['id'] == tid)['matches']
          .add(body);
      return http.Response(request.body, 201);
    }
    if (path.contains('/matches/') && request.method == 'DELETE') {
      final parts = path.split('/');
      final tid = parts[4];
      final mid = parts.last;
      (tournaments.firstWhere((t) => t['id'] == tid)['matches'] as List)
          .removeWhere((m) => m['id'] == mid);
      return http.Response('', 204);
    }
    if (path.contains('/tournaments/') && request.method == 'DELETE') {
      tournaments.removeWhere((t) => t['id'] == path.split('/').last);
      return http.Response('', 204);
    }
    if (path.endsWith('/tags') && request.method == 'GET') {
      return http.Response(jsonEncode(tags..sort()), 200);
    }
    if (path.endsWith('/tags') && request.method == 'POST') {
      final name = jsonDecode(request.body)['name'] as String;
      if (!tags.contains(name)) tags.add(name);
      return http.Response(request.body, 201);
    }
    if (path.contains('/tags/') && request.method == 'DELETE') {
      tags.remove(Uri.decodeComponent(path.split('/').last));
      return http.Response('', 204);
    }
    return http.Response('{"detail": "no route: $path"}', 404);
  }
}

ApiService service(FakeBackend backend, {String playerId = 'p1'}) =>
    ApiService(client: backend.client(), activePlayerId: () => playerId);

void main() {
  test('session with json-array drills and reflection round-trips the wire',
      () async {
    final backend = FakeBackend();
    final api = service(backend);

    await api.insertSession(_session);
    final loaded = await api.getSessions();

    expect(loaded, hasLength(1));
    final restored = loaded.single;
    expect(restored.drills, ['Multi-feed, front court', 'Net Play']);
    expect(restored.intensity, isNull);
    expect(restored.sessionGoal, 'Sharper net kills');
    expect(restored.reflectionAnswersJson, _session.reflectionAnswersJson);
    expect(backend.sessions.single['drills'],
        '["Multi-feed, front court","Net Play"]');
  });

  test('all calls scope urls to the active player id', () async {
    final backend = FakeBackend();
    final api = service(backend, playerId: 'player-42');

    await api.insertSession(_session);
    await api.getSessions();
    await api.getCustomTags();

    expect(
      backend.requests.every((r) => r.contains('/players/player-42/')),
      isTrue,
      reason: 'every url must be scoped to the active player',
    );
  });

  test('updateSession PUTs to the session id and deleteSession removes',
      () async {
    final backend = FakeBackend();
    final api = service(backend);
    await api.insertSession(_session);

    await api.updateSession(
        _session.copyWith(sessionGoal: 'Edited goal'));
    expect(backend.sessions.single['sessionGoal'], 'Edited goal');

    await api.deleteSession(_session.id);
    expect(backend.sessions, isEmpty);
  });

  test('insertSessions batches and hasAnySessions reads the flag', () async {
    final backend = FakeBackend();
    final api = service(backend);

    expect(await api.hasAnySessions(), isFalse);
    await api.insertSessions([_session]);
    expect(await api.hasAnySessions(), isTrue);
    expect(backend.requests, contains('POST /players/p1/sessions/batch'));
  });

  test('tournaments round-trip with nested matches', () async {
    final backend = FakeBackend();
    final api = service(backend);

    await api.insertTournament(_tournament);
    await api.insertMatch(_match);
    final loaded = await api.getTournaments();

    expect(loaded.single.name, 'Regional U13');
    expect(loaded.single.matches.single.scores, ['21-15', '21-18']);
    expect(loaded.single.matches.single.isWin, isTrue);
    expect(backend.tournaments.single['matches'].single['scores'],
        '21-15|21-18');

    await api.deleteMatch(_match.id);
    expect((await api.getTournaments()).single.matches, isEmpty);

    await api.deleteTournament(_tournament.id);
    expect(await api.getTournaments(), isEmpty);
  });

  test('custom tags get/insert/delete hit the tags routes', () async {
    final backend = FakeBackend();
    final api = service(backend);

    await api.insertCustomTag('Deception');
    await api.insertCustomTag('Shadow');
    expect(await api.getCustomTags(), ['Deception', 'Shadow']);

    await api.deleteCustomTag('Deception');
    expect(await api.getCustomTags(), ['Shadow']);
  });

  test('api errors surface as ApiException', () async {
    final api = ApiService(
      client: ApiClient(
        baseUrl: 'http://api.test/api/v1',
        inner: MockClient(
          (_) async =>
              http.Response(jsonEncode({'detail': 'player not found'}), 404),
        ),
      ),
      activePlayerId: () => 'ghost',
    );

    expect(api.getSessions, throwsA(isA<ApiException>()));
  });

  group('match logs', () {
    final log = MatchLog(
      id: 'ml1',
      date: DateTime(2026, 7, 12, 14, 30),
      opponent: 'Ken T.',
      eventContext: 'League round 3',
      scores: '21-15, 18-21, 21-19',
      isWin: true,
      gameplan: 'Attack the backhand',
      readinessScore: 4,
      performanceNotes: 'Net play broke down',
      keyMoments: 'Saved 2 game points',
      videoRef: '/videos/league-r3.mp4',
    );

    test('insertMatchLog then getMatchLogs round-trips the wire', () async {
      final backend = FakeBackend();
      final api = service(backend);

      await api.insertMatchLog(log);
      final loaded = await api.getMatchLogs();

      expect(loaded.single.toMap(), log.toMap());
      expect(backend.matchLogs.single['isWin'], 1,
          reason: 'isWin crosses the wire as a 0/1 int');
    });

    test('match-log urls scope to the active player', () async {
      final backend = FakeBackend();
      final api = service(backend, playerId: 'player-42');

      await api.insertMatchLog(log);
      await api.getMatchLogs();
      await api.hasAnyMatchLogs();

      expect(
        backend.requests.every((r) => r.contains('/players/player-42/')),
        isTrue,
      );
    });

    test('updateMatchLog PUTs to the log id and deleteMatchLog removes',
        () async {
      final backend = FakeBackend();
      final api = service(backend);
      await api.insertMatchLog(log);

      await api.updateMatchLog(log.copyWith(opponent: 'Mia W.'));
      expect(backend.matchLogs.single['opponent'], 'Mia W.');
      expect(backend.requests.last, 'PUT /players/p1/match-logs/ml1');

      await api.deleteMatchLog(log.id);
      expect(backend.matchLogs, isEmpty);
    });

    test('insertMatchLogs batches and hasAnyMatchLogs reflects state',
        () async {
      final backend = FakeBackend();
      final api = service(backend);

      expect(await api.hasAnyMatchLogs(), isFalse);
      await api.insertMatchLogs([log, log.copyWith(id: 'ml2')]);

      expect(backend.matchLogs, hasLength(2));
      expect(backend.requests, contains('POST /players/p1/match-logs/batch'));
      expect(await api.hasAnyMatchLogs(), isTrue);
    });
  });
}
