import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:badminton_flutter/models/match_log.dart';
import 'package:badminton_flutter/models/session.dart';
import 'package:badminton_flutter/models/tournament.dart';
import 'package:badminton_flutter/services/api_client.dart';
import 'package:badminton_flutter/services/api_service.dart';
import 'package:badminton_flutter/services/database_service.dart';

/// Explodes on any HTTP call — proves non-web code never reaches the api.
class _ThrowingApiService extends ApiService {
  _ThrowingApiService()
    : super(
        client: ApiClient(
          baseUrl: 'http://never.call',
          inner: MockClient(
            (request) async =>
                throw StateError('web api called on non-web: ${request.url}'),
          ),
        ),
        activePlayerId: () => throw StateError('web api used on non-web'),
      );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbName = 'database_service_test.db';
  });

  setUp(() async {
    await DatabaseService.resetForTests();
  });

  test('foreign_keys pragma is enabled on open', () async {
    // Force the DB open via any call, then inspect the pragma.
    await DatabaseService.getSessions();
    final result = await DatabaseService.debugRawQuery('PRAGMA foreign_keys');
    expect(
      result.first.values.first,
      1,
      reason: 'PRAGMA foreign_keys must be ON for this connection',
    );
  });

  test('deleting a tournament row cascades to matches via SQL', () async {
    final tournament = Tournament(
      id: const Uuid().v4(),
      name: 'Regional U13',
      date: DateTime(2026, 6, 1),
      location: 'Auckland',
      format: 'Knockout',
    );
    await DatabaseService.insertTournament(tournament);
    await DatabaseService.insertMatch(
      TournamentMatch(
        id: const Uuid().v4(),
        tournamentId: tournament.id,
        opponent: 'A. Rival',
        scores: const ['21-15', '21-18'],
        isWin: true,
      ),
    );

    // Delete the tournament row directly — NOT via deleteTournament(),
    // which removes matches manually. Only the FK cascade can clean up here.
    await DatabaseService.debugRawDelete(
      'DELETE FROM tournaments WHERE id = ?',
      [tournament.id],
    );

    final orphans = await DatabaseService.debugRawQuery(
      'SELECT * FROM matches WHERE tournamentId = ?',
      [tournament.id],
    );
    expect(
      orphans,
      isEmpty,
      reason: 'matches must cascade-delete with their tournament',
    );
  });

  test(
    'updateSession persists modified goal, drills, and reflection fields',
    () async {
      final original = TrainingSession(
        id: 'update-me',
        date: DateTime(2026, 7, 2),
        durationMinutes: 60,
        drills: const ['Footwork'],
        sessionGoal: 'Original goal',
        goalAchievementScore: 2,
      );
      await DatabaseService.insertSession(original);

      final edited = original.copyWith(
        date: DateTime(2026, 7, 3),
        durationMinutes: 90,
        drills: const ['Footwork', 'Smash, steep angle'],
        sessionGoal: 'Edited goal',
        goalAchievementScore: 5,
        playerRemarks: 'Felt strong',
        coachRemarks: 'Better base position',
        reflectionAnswersJson:
            '[{"questionKey":"Why did you set this goal for today?","answer":"edit"}]',
        notes: 'edited notes',
      );
      await DatabaseService.updateSession(edited);

      final loaded = (await DatabaseService.getSessions()).single;
      expect(loaded.id, 'update-me');
      expect(loaded.date, DateTime(2026, 7, 3));
      expect(loaded.durationMinutes, 90);
      expect(loaded.drills, ['Footwork', 'Smash, steep angle']);
      expect(loaded.sessionGoal, 'Edited goal');
      expect(loaded.goalAchievementScore, 5);
      expect(loaded.playerRemarks, 'Felt strong');
      expect(loaded.coachRemarks, 'Better base position');
      expect(loaded.reflectionAnswersJson, edited.reflectionAnswersJson);
      expect(loaded.notes, 'edited notes');
    },
  );

  test('updateSession leaves other sessions untouched', () async {
    final a = TrainingSession(
      id: 'session-a',
      date: DateTime(2026, 7, 1),
      durationMinutes: 30,
      drills: const ['Serve'],
    );
    final b = TrainingSession(
      id: 'session-b',
      date: DateTime(2026, 7, 2),
      durationMinutes: 45,
      drills: const ['Clear'],
    );
    await DatabaseService.insertSessions([a, b]);

    await DatabaseService.updateSession(a.copyWith(sessionGoal: 'changed'));

    final loaded = await DatabaseService.getSessions();
    expect(
      loaded.singleWhere((s) => s.id == 'session-a').sessionGoal,
      'changed',
    );
    expect(loaded.singleWhere((s) => s.id == 'session-b').sessionGoal, '');
  });

  test('custom tags: insert, list, delete round-trip', () async {
    await DatabaseService.insertCustomTag('Shadow Footwork');
    await DatabaseService.insertCustomTag('Multi-feed, front court');

    expect(await DatabaseService.getCustomTags(), [
      'Multi-feed, front court',
      'Shadow Footwork',
    ]);

    await DatabaseService.deleteCustomTag('Shadow Footwork');
    expect(await DatabaseService.getCustomTags(), ['Multi-feed, front court']);
  });

  test('custom tags: duplicate insert is a no-op', () async {
    await DatabaseService.insertCustomTag('Deception');
    await DatabaseService.insertCustomTag('Deception');

    expect(await DatabaseService.getCustomTags(), ['Deception']);
  });

  test('non-web paths never touch the web api', () async {
    // In the test environment kIsWeb is false; with a throwing ApiService
    // injected, any accidental web-branch call would explode.
    DatabaseService.webApi = _ThrowingApiService();
    addTearDown(() => DatabaseService.webApi = null);

    final session = TrainingSession(
      id: const Uuid().v4(),
      date: DateTime(2026, 7, 2),
      durationMinutes: 45,
      drills: const ['Serve'],
    );
    await DatabaseService.insertSession(session);
    await DatabaseService.updateSession(session.copyWith(notes: 'edited'));
    expect(await DatabaseService.getSessions(), hasLength(1));
    expect(await DatabaseService.hasAnySessions(), isTrue);
    await DatabaseService.insertCustomTag('Deception');
    expect(await DatabaseService.getCustomTags(), ['Deception']);
    await DatabaseService.deleteSession(session.id);
  });

  test('insertSessions then getSessions round-trips', () async {
    final session = TrainingSession(
      id: const Uuid().v4(),
      date: DateTime(2026, 7, 1),
      durationMinutes: 60,
      drills: const ['Footwork', 'Smash'],
      intensity: 4,
      notes: 'Round-trip test',
    );
    await DatabaseService.insertSessions([session]);

    final loaded = await DatabaseService.getSessions();
    expect(loaded, hasLength(1));
    expect(loaded.first.id, session.id);
    expect(loaded.first.drills, session.drills);
    expect(loaded.first.intensity, 4);
  });

  group('match logs', () {
    MatchLog log({String? id, DateTime? date}) => MatchLog(
      id: id ?? const Uuid().v4(),
      date: date ?? DateTime(2026, 7, 12, 14, 30),
      opponent: 'Ken T.',
      eventContext: 'League round 3',
      scores: '21-15, 18-21, 21-19',
      isWin: true,
      gameplan: 'Attack the backhand',
      readinessScore: 4,
      performanceNotes: 'Net play broke down in game 2',
      keyMoments: 'Saved 2 game points',
      videoRef: '/videos/league-r3.mp4',
    );

    test('insert and read back a match log round-trips all fields', () async {
      final original = log();
      await DatabaseService.insertMatchLog(original);

      final loaded = await DatabaseService.getMatchLogs();
      expect(loaded, hasLength(1));
      expect(loaded.first.toMap(), original.toMap());
    });

    test('getMatchLogs returns newest first', () async {
      await DatabaseService.insertMatchLog(
        log(id: 'old', date: DateTime(2026, 7, 1)),
      );
      await DatabaseService.insertMatchLog(
        log(id: 'new', date: DateTime(2026, 7, 10)),
      );

      final ids = (await DatabaseService.getMatchLogs()).map((l) => l.id);
      expect(ids, ['new', 'old']);
    });

    test(
      'updateMatchLog replaces fields and leaves others untouched',
      () async {
        final a = log(id: 'a');
        final b = log(id: 'b', date: DateTime(2026, 7, 1));
        await DatabaseService.insertMatchLog(a);
        await DatabaseService.insertMatchLog(b);

        await DatabaseService.updateMatchLog(
          a.copyWith(opponent: 'Mia W.', isWin: false),
        );

        final loaded = await DatabaseService.getMatchLogs();
        expect(loaded.first.opponent, 'Mia W.');
        expect(loaded.first.isWin, false);
        expect(loaded.last.toMap(), b.toMap());
      },
    );

    test('deleteMatchLog removes the row', () async {
      final l = log();
      await DatabaseService.insertMatchLog(l);
      await DatabaseService.deleteMatchLog(l.id);

      expect(await DatabaseService.getMatchLogs(), isEmpty);
    });

    test('hasAnyMatchLogs flips once a log exists', () async {
      expect(await DatabaseService.hasAnyMatchLogs(), isFalse);
      await DatabaseService.insertMatchLog(log());
      expect(await DatabaseService.hasAnyMatchLogs(), isTrue);
    });

    test('insertMatchLogs batch round-trips', () async {
      await DatabaseService.insertMatchLogs([log(id: 'b1'), log(id: 'b2')]);

      expect(await DatabaseService.getMatchLogs(), hasLength(2));
    });
  });
}
