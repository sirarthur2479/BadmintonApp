import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/match_log.dart';
import '../models/session.dart';
import '../models/tournament.dart';
import '../models/upload_task.dart';
import 'api_service.dart';

/// On web: data lives on the self-hosted backend (set [webApi] at startup).
/// On iOS/Android: data is persisted via local sqflite, offline-first.
class DatabaseService {
  static Database? _db;

  /// The web build's server-backed data layer; null on mobile.
  static ApiService? webApi;

  // ── sqflite init ─────────────────────────────────────────────────────────
  static Future<Database> get _database async {
    _db ??= await _initDb();
    return _db!;
  }

  /// Overridable so parallel test isolates don't share one DB file.
  @visibleForTesting
  static String dbName = 'badminton.db';

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, dbName);

    return openDatabase(
      path,
      version: 5,
      // sqflite leaves foreign keys OFF by default; without this the
      // matches-table ON DELETE CASCADE is inert.
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onUpgrade: _upgrade,
      onCreate: (db, version) async {
        await _createSessionsTable(db);
        await _createCustomTagsTable(db);
        await _createUploadQueueTable(db);
        await _createMatchLogsTable(db);
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
    );
  }

  /// Schema v2: intensity is nullable (legacy rating), goal/reflection
  /// columns added, drills stored as a JSON array.
  static Future<void> _createSessionsTable(
    DatabaseExecutor db, {
    String name = 'sessions',
  }) async {
    await db.execute('''
      CREATE TABLE $name (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        durationMinutes INTEGER NOT NULL,
        drills TEXT NOT NULL,
        intensity INTEGER,
        notes TEXT NOT NULL,
        photoPath TEXT,
        sessionGoal TEXT NOT NULL DEFAULT '',
        goalAchievementScore INTEGER NOT NULL DEFAULT 3,
        playerRemarks TEXT NOT NULL DEFAULT '',
        coachRemarks TEXT NOT NULL DEFAULT '',
        reflectionAnswersJson TEXT NOT NULL DEFAULT '[]',
        analysisReportPath TEXT,
        analysisCourtMapPath TEXT
      )
    ''');
  }

  static Future<void> _upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      // v1 declared intensity NOT NULL, so the table must be rebuilt, not
      // ALTERed. Drills switch from comma-joined text to a JSON array in the
      // same pass.
      await db.transaction((txn) async {
        await _createSessionsTable(txn, name: 'sessions_new');
        final rows = await txn.query('sessions');
        for (final row in rows) {
          final rawDrills = row['drills'] as String? ?? '';
          await txn.insert('sessions_new', {
            ...row,
            'drills': jsonEncode(rawDrills.isEmpty ? [] : rawDrills.split(',')),
          });
        }
        await txn.execute('DROP TABLE sessions');
        await txn.execute('ALTER TABLE sessions_new RENAME TO sessions');
        await _createCustomTagsTable(txn);
      });
    }
    if (oldVersion < 3) {
      // v3: mobile-only video upload queue (TASK-032).
      await _createUploadQueueTable(db);
    }
    if (oldVersion >= 2 && oldVersion < 4) {
      // v4: downloaded analysis artifacts attach to the session (TASK-034).
      // A v1 upgrader skips this — its rebuild above already created the
      // sessions table at the current shape, columns included.
      await db.execute(
          'ALTER TABLE sessions ADD COLUMN analysisReportPath TEXT');
      await db.execute(
          'ALTER TABLE sessions ADD COLUMN analysisCourtMapPath TEXT');
    }
  }

  static Future<void> _createUploadQueueTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE upload_queue (
        id TEXT PRIMARY KEY,
        sessionId TEXT NOT NULL,
        playerId TEXT NOT NULL,
        mode TEXT NOT NULL,
        filePath TEXT NOT NULL,
        totalBytes INTEGER NOT NULL,
        sentBytes INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'pending',
        tusUrl TEXT,
        error TEXT
      )
    ''');
  }

  static Future<void> _createCustomTagsTable(DatabaseExecutor db) async {
    await db.execute('CREATE TABLE custom_tags (name TEXT PRIMARY KEY)');
  }

  /// Schema v5: standalone per-match reflection logs (TASK-037). Like
  /// sessions, no playerId column — mobile is single-player offline; the
  /// backend scopes by player via the route path.
  static Future<void> _createMatchLogsTable(DatabaseExecutor db) async {
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
  }

  // ── Upload queue (mobile-only: web has no video pipeline, so these
  // deliberately have no webApi mirror) ──────────────────────────────────

  static Future<void> insertUploadTask(UploadTask task) async {
    final db = await _database;
    await db.insert('upload_queue', task.toMap());
  }

  static Future<List<UploadTask>> getUploadTasks() async {
    final db = await _database;
    final maps = await db.query('upload_queue');
    return maps.map(UploadTask.fromMap).toList();
  }

  static Future<void> updateUploadTask(UploadTask task) async {
    final db = await _database;
    await db.update(
      'upload_queue',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  static Future<void> deleteUploadTask(String id) async {
    final db = await _database;
    await db.delete('upload_queue', where: 'id = ?', whereArgs: [id]);
  }

  // ── Test hooks ───────────────────────────────────────────────────────────

  /// Closes and deletes the database so each test starts fresh.
  @visibleForTesting
  static Future<void> resetForTests() async {
    await _db?.close();
    _db = null;
    final path = join(await getDatabasesPath(), dbName);
    await deleteDatabase(path);
  }

  @visibleForTesting
  static Future<List<Map<String, Object?>>> debugRawQuery(
    String sql, [
    List<Object?>? args,
  ]) async {
    final db = await _database;
    return db.rawQuery(sql, args);
  }

  @visibleForTesting
  static Future<int> debugRawDelete(String sql, [List<Object?>? args]) async {
    final db = await _database;
    return db.rawDelete(sql, args);
  }

  // ── Sessions ─────────────────────────────────────────────────────────────

  static Future<List<TrainingSession>> getSessions() async {
    if (kIsWeb) return webApi!.getSessions();
    final db = await _database;
    final maps = await db.query('sessions', orderBy: 'date DESC');
    return maps.map(TrainingSession.fromMap).toList();
  }

  static Future<void> insertSession(TrainingSession session) async {
    if (kIsWeb) return webApi!.insertSession(session);
    final db = await _database;
    await db.insert(
      'sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> updateSession(TrainingSession session) async {
    if (kIsWeb) return webApi!.updateSession(session);
    final db = await _database;
    await db.update(
      'sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  static Future<void> deleteSession(String id) async {
    if (kIsWeb) return webApi!.deleteSession(id);
    final db = await _database;
    await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  static Future<bool> hasAnySessions() async {
    if (kIsWeb) return webApi!.hasAnySessions();
    final db = await _database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM sessions');
    return (result.first['count'] as int) > 0;
  }

  static Future<void> insertSessions(List<TrainingSession> sessions) async {
    if (kIsWeb) return webApi!.insertSessions(sessions);
    final db = await _database;
    final batch = db.batch();
    for (final s in sessions) {
      batch.insert(
        'sessions',
        s.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  // ── Custom drill tags ────────────────────────────────────────────────────

  static Future<List<String>> getCustomTags() async {
    if (kIsWeb) return webApi!.getCustomTags();
    final db = await _database;
    final rows = await db.query('custom_tags', orderBy: 'name ASC');
    return rows.map((r) => r['name'] as String).toList();
  }

  static Future<void> insertCustomTag(String name) async {
    if (kIsWeb) return webApi!.insertCustomTag(name);
    final db = await _database;
    await db.insert('custom_tags', {
      'name': name,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<void> deleteCustomTag(String name) async {
    if (kIsWeb) return webApi!.deleteCustomTag(name);
    final db = await _database;
    await db.delete('custom_tags', where: 'name = ?', whereArgs: [name]);
  }

  // ── Tournaments ───────────────────────────────────────────────────────────

  static Future<List<Tournament>> getTournaments() async {
    if (kIsWeb) return webApi!.getTournaments();
    final db = await _database;
    final tournamentMaps = await db.query('tournaments', orderBy: 'date DESC');
    final List<Tournament> tournaments = [];
    for (final tMap in tournamentMaps) {
      final matchMaps = await db.query(
        'matches',
        where: 'tournamentId = ?',
        whereArgs: [tMap['id']],
      );
      final matches = matchMaps.map(TournamentMatch.fromMap).toList();
      tournaments.add(Tournament.fromMap(tMap, matches: matches));
    }
    return tournaments;
  }

  static Future<void> insertTournament(Tournament tournament) async {
    if (kIsWeb) return webApi!.insertTournament(tournament);
    final db = await _database;
    await db.insert(
      'tournaments',
      tournament.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> deleteTournament(String id) async {
    if (kIsWeb) return webApi!.deleteTournament(id);
    final db = await _database;
    await db.delete('tournaments', where: 'id = ?', whereArgs: [id]);
    await db.delete('matches', where: 'tournamentId = ?', whereArgs: [id]);
  }

  static Future<void> insertMatch(TournamentMatch match) async {
    if (kIsWeb) return webApi!.insertMatch(match);
    final db = await _database;
    await db.insert(
      'matches',
      match.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> deleteMatch(String id) async {
    if (kIsWeb) return webApi!.deleteMatch(id);
    final db = await _database;
    await db.delete('matches', where: 'id = ?', whereArgs: [id]);
  }

  // ── Match logs ───────────────────────────────────────────────────────────

  static Future<List<MatchLog>> getMatchLogs() async {
    final db = await _database;
    final maps = await db.query('match_logs', orderBy: 'date DESC');
    return maps.map(MatchLog.fromMap).toList();
  }

  static Future<void> insertMatchLog(MatchLog log) async {
    final db = await _database;
    await db.insert(
      'match_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> insertMatchLogs(List<MatchLog> logs) async {
    final db = await _database;
    final batch = db.batch();
    for (final log in logs) {
      batch.insert(
        'match_logs',
        log.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<void> updateMatchLog(MatchLog log) async {
    final db = await _database;
    await db.update(
      'match_logs',
      log.toMap(),
      where: 'id = ?',
      whereArgs: [log.id],
    );
  }

  static Future<void> deleteMatchLog(String id) async {
    final db = await _database;
    await db.delete('match_logs', where: 'id = ?', whereArgs: [id]);
  }

  static Future<bool> hasAnyMatchLogs() async {
    final db = await _database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM match_logs');
    return (result.first['count'] as int) > 0;
  }
}
