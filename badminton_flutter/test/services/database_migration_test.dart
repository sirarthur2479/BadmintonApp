import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:badminton_flutter/models/match_log.dart';
import 'package:badminton_flutter/models/point_record.dart';
import 'package:badminton_flutter/models/session.dart';
import 'package:badminton_flutter/services/database_service.dart';

/// Creates the database file exactly as schema v1 shipped it and seeds one
/// legacy row, so opening it through DatabaseService exercises onUpgrade.
Future<void> createV1Database() async {
  final path = join(await getDatabasesPath(), DatabaseService.dbName);
  final db = await databaseFactory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sessions (
            id TEXT PRIMARY KEY,
            date TEXT NOT NULL,
            durationMinutes INTEGER NOT NULL,
            drills TEXT NOT NULL,
            intensity INTEGER NOT NULL,
            notes TEXT NOT NULL,
            photoPath TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE tournaments (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            date TEXT NOT NULL,
            location TEXT NOT NULL,
            format TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE matches (
            id TEXT PRIMARY KEY,
            tournamentId TEXT NOT NULL,
            opponent TEXT NOT NULL,
            scores TEXT NOT NULL,
            isWin INTEGER NOT NULL,
            notes TEXT,
            FOREIGN KEY (tournamentId) REFERENCES tournaments (id) ON DELETE CASCADE
          )
        ''');
      },
    ),
  );
  await db.insert('sessions', {
    'id': 'legacy-session-1',
    'date': DateTime(2026, 3, 10).toIso8601String(),
    'durationMinutes': 75,
    'drills': 'Smash,Footwork,Net Play',
    'intensity': 4,
    'notes': 'pre-migration row',
    'photoPath': null,
  });
  await db.close();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbName = 'database_migration_test.db';
  });

  setUp(() async {
    await DatabaseService.resetForTests();
    await createV1Database();
  });

  test(
    'migration v1→v2 preserves sessions and converts comma drills to JSON',
    () async {
      final loaded = await DatabaseService.getSessions();

      expect(loaded, hasLength(1));
      final s = loaded.first;
      expect(s.id, 'legacy-session-1');
      expect(s.drills, ['Smash', 'Footwork', 'Net Play']);
      expect(s.intensity, 4);
      expect(s.durationMinutes, 75);
      expect(s.notes, 'pre-migration row');

      // The stored column itself must be JSON now, not merely readable via
      // the model's legacy fallback.
      final raw = await DatabaseService.debugRawQuery(
        'SELECT drills FROM sessions WHERE id = ?',
        ['legacy-session-1'],
      );
      expect(raw.first['drills'], '["Smash","Footwork","Net Play"]');
    },
  );

  test('migration leaves new columns at defaults for legacy rows', () async {
    final s = (await DatabaseService.getSessions()).single;

    expect(s.sessionGoal, '');
    expect(s.goalAchievementScore, 3);
    expect(s.playerRemarks, '');
    expect(s.coachRemarks, '');
    expect(s.reflectionAnswersJson, '[]');
  });

  test('migration creates the custom_tags table', () async {
    await DatabaseService.insertCustomTag('From v1 upgrade');

    expect(await DatabaseService.getCustomTags(), ['From v1 upgrade']);
  });

  test('migrated database accepts a session with null intensity', () async {
    final session = TrainingSession(
      id: 'post-migration-1',
      date: DateTime(2026, 7, 5),
      durationMinutes: 60,
      drills: const ['Multi-feed, front court'],
      sessionGoal: 'Faster recovery to base',
    );

    await DatabaseService.insertSession(session);

    final loaded = await DatabaseService.getSessions();
    final restored = loaded.singleWhere((s) => s.id == 'post-migration-1');
    expect(restored.intensity, isNull);
    expect(restored.drills, ['Multi-feed, front court']);
    expect(restored.sessionGoal, 'Faster recovery to base');
  });

  test(
    'migration creates the match_logs table and keeps legacy sessions',
    () async {
      // v5: the upgraded database must accept match logs...
      await DatabaseService.insertMatchLog(
        MatchLog(
          id: 'post-migration-log',
          date: DateTime(2026, 7, 12),
          opponent: 'Ken T.',
          isWin: true,
        ),
      );

      final logs = await DatabaseService.getMatchLogs();
      expect(logs.single.id, 'post-migration-log');

      // ...without disturbing the pre-migration data.
      expect(
        (await DatabaseService.getSessions()).single.id,
        'legacy-session-1',
      );
    },
  );

  test(
    'v1-chain migration creates the point_records table (v6)',
    () async {
      await DatabaseService.insertMatchLog(
        MatchLog(
          id: 'post-migration-log',
          date: DateTime(2026, 7, 12),
          opponent: 'Ken T.',
          isWin: true,
        ),
      );

      await DatabaseService.insertPointRecord(
        PointRecord(
          id: 'post-migration-pt',
          matchLogId: 'post-migration-log',
          game: 1,
          indexInGame: 1,
          server: 'player',
          winner: 'player',
          playerScore: 1,
          opponentScore: 0,
          endingType: 'winner',
        ),
      );

      final points = await DatabaseService.getPointRecords(
        'post-migration-log',
      );
      expect(points.single.id, 'post-migration-pt');
    },
  );

  test('a real v5 database upgrades to v6 preserving match logs', () async {
    // Rebuild the fixture as v5 shipped it (schema v5 = current tables minus
    // point_records), seed a log, then reopen through DatabaseService.
    await DatabaseService.resetForTests();
    final path = join(await getDatabasesPath(), DatabaseService.dbName);
    final v5 = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 5,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE match_logs (
              id TEXT PRIMARY KEY,
              date TEXT NOT NULL,
              opponent TEXT NOT NULL,
              eventContext TEXT NOT NULL DEFAULT '',
              scores TEXT NOT NULL DEFAULT '',
              isWin INTEGER NOT NULL,
              gameplan TEXT NOT NULL DEFAULT '',
              readinessScore INTEGER NOT NULL DEFAULT 3,
              performanceNotes TEXT NOT NULL DEFAULT '',
              keyMoments TEXT NOT NULL DEFAULT '',
              videoRef TEXT
            )
          ''');
        },
      ),
    );
    await v5.insert('match_logs', {
      'id': 'v5-log',
      'date': DateTime(2026, 7, 10).toIso8601String(),
      'opponent': 'Mia W.',
      'isWin': 0,
    });
    await v5.close();

    final logs = await DatabaseService.getMatchLogs();
    expect(logs.single.id, 'v5-log');

    // And the new table exists and is usable.
    await DatabaseService.insertPointRecord(
      PointRecord(
        id: 'v6-pt',
        matchLogId: 'v5-log',
        game: 1,
        indexInGame: 1,
        server: 'opponent',
        winner: 'opponent',
        playerScore: 0,
        opponentScore: 1,
        endingType: 'unforcedError',
      ),
    );
    expect((await DatabaseService.getPointRecords('v5-log')).length, 1);
  });
}
