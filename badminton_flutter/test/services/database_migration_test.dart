import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

  test('migration v1→v2 preserves sessions and converts comma drills to JSON',
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
        'SELECT drills FROM sessions WHERE id = ?', ['legacy-session-1']);
    expect(raw.first['drills'], '["Smash","Footwork","Net Play"]');
  });

  test('migration leaves new columns at defaults for legacy rows', () async {
    final s = (await DatabaseService.getSessions()).single;

    expect(s.sessionGoal, '');
    expect(s.goalAchievementScore, 3);
    expect(s.playerRemarks, '');
    expect(s.coachRemarks, '');
    expect(s.reflectionAnswersJson, '[]');
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
}
