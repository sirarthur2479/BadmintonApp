import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/session.dart';
import '../models/tournament.dart';

/// On web: all data is in-memory (no persistence — web is preview-only).
/// On iOS/Android: data is persisted via sqflite.
class DatabaseService {
  static Database? _db;

  // ── In-memory stores (web only) ──────────────────────────────────────────
  static final List<TrainingSession> _webSessions = [];
  static final List<Tournament> _webTournaments = [];

  // ── sqflite init ─────────────────────────────────────────────────────────
  static Future<Database> get _database async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'badminton.db');

    return openDatabase(
      path,
      version: 1,
      // sqflite leaves foreign keys OFF by default; without this the
      // matches-table ON DELETE CASCADE is inert.
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
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
    );
  }

  // ── Test hooks ───────────────────────────────────────────────────────────

  /// Closes and deletes the database so each test starts fresh.
  @visibleForTesting
  static Future<void> resetForTests() async {
    await _db?.close();
    _db = null;
    final path = join(await getDatabasesPath(), 'badminton.db');
    await deleteDatabase(path);
  }

  @visibleForTesting
  static Future<List<Map<String, Object?>>> debugRawQuery(String sql,
      [List<Object?>? args]) async {
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
    if (kIsWeb) {
      return List.from(_webSessions)
        ..sort((a, b) => b.date.compareTo(a.date));
    }
    final db = await _database;
    final maps = await db.query('sessions', orderBy: 'date DESC');
    return maps.map(TrainingSession.fromMap).toList();
  }

  static Future<void> insertSession(TrainingSession session) async {
    if (kIsWeb) {
      _webSessions.add(session);
      return;
    }
    final db = await _database;
    await db.insert('sessions', session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> deleteSession(String id) async {
    if (kIsWeb) {
      _webSessions.removeWhere((s) => s.id == id);
      return;
    }
    final db = await _database;
    await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  static Future<bool> hasAnySessions() async {
    if (kIsWeb) return _webSessions.isNotEmpty;
    final db = await _database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM sessions');
    return (result.first['count'] as int) > 0;
  }

  static Future<void> insertSessions(List<TrainingSession> sessions) async {
    if (kIsWeb) {
      _webSessions.addAll(sessions);
      return;
    }
    final db = await _database;
    final batch = db.batch();
    for (final s in sessions) {
      batch.insert('sessions', s.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  // ── Tournaments ───────────────────────────────────────────────────────────

  static Future<List<Tournament>> getTournaments() async {
    if (kIsWeb) {
      return List.from(_webTournaments)
        ..sort((a, b) => b.date.compareTo(a.date));
    }
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
    if (kIsWeb) {
      _webTournaments.add(tournament);
      return;
    }
    final db = await _database;
    await db.insert('tournaments', tournament.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> deleteTournament(String id) async {
    if (kIsWeb) {
      _webTournaments.removeWhere((t) => t.id == id);
      return;
    }
    final db = await _database;
    await db.delete('tournaments', where: 'id = ?', whereArgs: [id]);
    await db.delete('matches', where: 'tournamentId = ?', whereArgs: [id]);
  }

  static Future<void> insertMatch(TournamentMatch match) async {
    if (kIsWeb) {
      final idx = _webTournaments.indexWhere((t) => t.id == match.tournamentId);
      if (idx >= 0) {
        _webTournaments[idx] = _webTournaments[idx]
            .copyWith(matches: [..._webTournaments[idx].matches, match]);
      }
      return;
    }
    final db = await _database;
    await db.insert('matches', match.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> deleteMatch(String id) async {
    if (kIsWeb) {
      for (int i = 0; i < _webTournaments.length; i++) {
        final t = _webTournaments[i];
        if (t.matches.any((m) => m.id == id)) {
          _webTournaments[i] =
              t.copyWith(matches: t.matches.where((m) => m.id != id).toList());
          break;
        }
      }
      return;
    }
    final db = await _database;
    await db.delete('matches', where: 'id = ?', whereArgs: [id]);
  }
}
