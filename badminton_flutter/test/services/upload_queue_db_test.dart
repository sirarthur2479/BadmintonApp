import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:badminton_flutter/models/upload_task.dart';
import 'package:badminton_flutter/services/database_service.dart';

const _task = UploadTask(
  id: 'ut-1',
  sessionId: 'sess-1',
  playerId: 'pl-1',
  mode: 'footwork',
  filePath: '/videos/clip.mp4',
  totalBytes: 2048,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    DatabaseService.dbName = 'upload_queue_test.db';
    await DatabaseService.resetForTests();
  });

  test('upload task inserts and reads back', () async {
    await DatabaseService.insertUploadTask(_task);

    final tasks = await DatabaseService.getUploadTasks();

    expect(tasks, hasLength(1));
    expect(tasks.single.id, 'ut-1');
    expect(tasks.single.status, UploadStatus.pending);
    expect(tasks.single.sentBytes, 0);
  });

  test('update rewrites progress and status', () async {
    await DatabaseService.insertUploadTask(_task);

    await DatabaseService.updateUploadTask(
      _task.copyWith(
        sentBytes: 1024,
        status: UploadStatus.uploading,
        tusUrl: 'http://server/api/v1/uploads/u-1',
      ),
    );

    final restored = (await DatabaseService.getUploadTasks()).single;
    expect(restored.sentBytes, 1024);
    expect(restored.status, UploadStatus.uploading);
    expect(restored.tusUrl, 'http://server/api/v1/uploads/u-1');
  });

  test('delete removes the row', () async {
    await DatabaseService.insertUploadTask(_task);

    await DatabaseService.deleteUploadTask('ut-1');

    expect(await DatabaseService.getUploadTasks(), isEmpty);
  });

  test('v2 to v3 migration adds upload_queue without touching sessions',
      () async {
    // The other tests run onCreate at v3; this one opens a database created
    // at v2 (no upload_queue) so onUpgrade must add the table.
    await DatabaseService.resetForTests();
    final path = join(await getDatabasesPath(), DatabaseService.dbName);
    final v2 = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          await db.execute('CREATE TABLE sessions (id TEXT PRIMARY KEY, '
              'date TEXT NOT NULL, durationMinutes INTEGER NOT NULL, '
              'drills TEXT NOT NULL, intensity INTEGER, notes TEXT NOT NULL, '
              "photoPath TEXT, sessionGoal TEXT NOT NULL DEFAULT '', "
              'goalAchievementScore INTEGER NOT NULL DEFAULT 3, '
              "playerRemarks TEXT NOT NULL DEFAULT '', "
              "coachRemarks TEXT NOT NULL DEFAULT '', "
              "reflectionAnswersJson TEXT NOT NULL DEFAULT '[]')");
          await db.execute('CREATE TABLE custom_tags (name TEXT PRIMARY KEY)');
          await db.execute('CREATE TABLE tournaments (id TEXT PRIMARY KEY, '
              'name TEXT NOT NULL, date TEXT NOT NULL, location TEXT NOT '
              'NULL, format TEXT NOT NULL)');
          await db.execute('CREATE TABLE matches (id TEXT PRIMARY KEY, '
              'tournamentId TEXT NOT NULL, opponent TEXT NOT NULL, scores '
              'TEXT NOT NULL, isWin INTEGER NOT NULL, notes TEXT)');
        },
      ),
    );
    await v2.insert('sessions', {
      'id': 'legacy-1',
      'date': '2026-07-01T00:00:00.000',
      'durationMinutes': 60,
      'drills': '["Smash"]',
      'notes': '',
    });
    await v2.close();

    await DatabaseService.insertUploadTask(_task);

    expect((await DatabaseService.getUploadTasks()).single.id, 'ut-1');
    final sessions = await DatabaseService.getSessions();
    expect(sessions.single.id, 'legacy-1');
  });
}
