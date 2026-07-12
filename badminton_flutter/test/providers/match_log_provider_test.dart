import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:badminton_flutter/models/match_log.dart';
import 'package:badminton_flutter/providers/match_log_provider.dart';
import 'package:badminton_flutter/services/database_service.dart';

MatchLog _log({String? id, DateTime? date, bool isWin = true}) => MatchLog(
  id: id ?? const Uuid().v4(),
  date: date ?? DateTime(2026, 7, 12),
  opponent: 'Ken T.',
  isWin: isWin,
);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbName = 'match_log_provider_test.db';
  });

  setUp(() async {
    await DatabaseService.resetForTests();
  });

  test('loadMatchLogs populates from the database once', () async {
    await DatabaseService.insertMatchLog(_log(id: 'preexisting'));

    final provider = MatchLogProvider();
    await provider.loadMatchLogs();
    expect(provider.matchLogs.single.id, 'preexisting');

    // A second load is a no-op guard, not a reload.
    await DatabaseService.insertMatchLog(_log(id: 'sneaked-in'));
    await provider.loadMatchLogs();
    expect(provider.matchLogs, hasLength(1));
  });

  test('refresh reloads from the DB unconditionally', () async {
    final provider = MatchLogProvider();
    await provider.loadMatchLogs();

    await DatabaseService.insertMatchLog(_log(id: 'external'));
    await provider.refresh();

    expect(provider.matchLogs.single.id, 'external');
  });

  test('addMatchLog persists and prepends to the list', () async {
    final provider = MatchLogProvider();
    await provider.loadMatchLogs();

    var notified = 0;
    provider.addListener(() => notified++);
    await provider.addMatchLog(_log(id: 'added'));

    expect(provider.matchLogs.single.id, 'added');
    expect(notified, 1);
    expect(
      (await DatabaseService.getMatchLogs()).single.id,
      'added',
      reason: 'must persist through DatabaseService',
    );
  });

  test('updateMatchLog replaces the item and keeps date-desc order', () async {
    final provider = MatchLogProvider();
    await provider.loadMatchLogs();
    final older = _log(id: 'older', date: DateTime(2026, 7, 1));
    final newer = _log(id: 'newer', date: DateTime(2026, 7, 10));
    await provider.addMatchLog(older);
    await provider.addMatchLog(newer);

    // Move the older log to the most recent date: it must resort to front.
    await provider.updateMatchLog(
      older.copyWith(date: DateTime(2026, 7, 11), opponent: 'Mia W.'),
    );

    expect(provider.matchLogs.map((l) => l.id), ['older', 'newer']);
    expect(provider.matchLogs.first.opponent, 'Mia W.');
    expect(
      (await DatabaseService.getMatchLogs()).first.opponent,
      'Mia W.',
      reason: 'update must persist',
    );
  });

  test('wins and losses count isWin flags, latestLog is newest', () async {
    final provider = MatchLogProvider();
    await provider.loadMatchLogs();

    expect(provider.latestLog, isNull);

    await provider.addMatchLog(
      _log(id: 'w1', date: DateTime(2026, 7, 1), isWin: true),
    );
    await provider.addMatchLog(
      _log(id: 'l1', date: DateTime(2026, 7, 5), isWin: false),
    );
    await provider.addMatchLog(
      _log(id: 'w2', date: DateTime(2026, 7, 10), isWin: true),
    );

    expect(provider.wins, 2);
    expect(provider.losses, 1);
    expect(provider.latestLog!.id, 'w2');
  });

  test('deleteMatchLog removes from db and memory', () async {
    final provider = MatchLogProvider();
    await provider.loadMatchLogs();
    await provider.addMatchLog(_log(id: 'doomed'));

    await provider.deleteMatchLog('doomed');

    expect(provider.matchLogs, isEmpty);
    expect(await DatabaseService.getMatchLogs(), isEmpty);
  });
}
