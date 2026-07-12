import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:badminton_flutter/models/match_log.dart';
import 'package:badminton_flutter/models/point_record.dart';
import 'package:badminton_flutter/providers/point_record_provider.dart';
import 'package:badminton_flutter/services/database_service.dart';

MatchLog _log(String id) => MatchLog(
  id: id,
  date: DateTime(2026, 7, 12),
  opponent: 'Ken T.',
  isWin: true,
);

PointRecord _point(
  String id, {
  String matchLogId = 'log-1',
  int game = 1,
  int indexInGame = 1,
}) => PointRecord(
  id: id,
  matchLogId: matchLogId,
  game: game,
  indexInGame: indexInGame,
  server: 'player',
  winner: 'player',
  playerScore: 1,
  opponentScore: 0,
  endingType: 'winner',
);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbName = 'point_record_provider_test.db';
  });

  setUp(() async {
    await DatabaseService.resetForTests();
    await DatabaseService.insertMatchLog(_log('log-1'));
  });

  test('loadFor populates points for a match log ordered', () async {
    await DatabaseService.insertPointRecord(
      _point('pt-2', game: 1, indexInGame: 2),
    );
    await DatabaseService.insertPointRecord(
      _point('pt-1', game: 1, indexInGame: 1),
    );

    final provider = PointRecordProvider();
    await provider.loadFor('log-1');

    expect(provider.points.map((p) => p.id).toList(), ['pt-1', 'pt-2']);
  });

  test('loadFor caches per log and refresh reloads', () async {
    final provider = PointRecordProvider();
    await provider.loadFor('log-1');

    await DatabaseService.insertPointRecord(_point('external'));
    await provider.loadFor('log-1');
    expect(provider.points, isEmpty, reason: 'same-log reload is a no-op');

    await provider.refresh();
    expect(provider.points.single.id, 'external');
  });

  test('addPoint persists, appends, and notifies', () async {
    final provider = PointRecordProvider();
    await provider.loadFor('log-1');
    var notified = 0;
    provider.addListener(() => notified++);

    await provider.addPoint(_point('pt-1'));

    expect(provider.points.single.id, 'pt-1');
    expect(notified, 1);
    expect(
      (await DatabaseService.getPointRecords('log-1')).single.id,
      'pt-1',
    );
  });

  test('undoLast removes the newest point by game and index', () async {
    final provider = PointRecordProvider();
    await provider.loadFor('log-1');
    await provider.addPoint(_point('pt-1', indexInGame: 1));
    await provider.addPoint(_point('pt-2', indexInGame: 2));

    await provider.undoLast();

    expect(provider.points.single.id, 'pt-1');
    expect(
      (await DatabaseService.getPointRecords('log-1')).single.id,
      'pt-1',
    );
  });

  test('undoLast on empty is a no-op', () async {
    final provider = PointRecordProvider();
    await provider.loadFor('log-1');

    await provider.undoLast();

    expect(provider.points, isEmpty);
  });

  test('clearAndReplace swaps the full set', () async {
    final provider = PointRecordProvider();
    await provider.loadFor('log-1');
    await provider.addPoint(_point('old-1'));

    await provider.clearAndReplace('log-1', [
      _point('new-1', indexInGame: 1),
      _point('new-2', indexInGame: 2),
    ]);

    expect(provider.points.map((p) => p.id).toList(), ['new-1', 'new-2']);
    final persisted = await DatabaseService.getPointRecords('log-1');
    expect(persisted.map((p) => p.id).toList(), ['new-1', 'new-2']);
  });

  test('allPoints spans match logs without touching the current view', () async {
    await DatabaseService.insertMatchLog(_log('log-2'));
    await DatabaseService.insertPointRecord(_point('pt-a'));
    await DatabaseService.insertPointRecord(
      _point('pt-b', matchLogId: 'log-2'),
    );

    final provider = PointRecordProvider();
    await provider.loadFor('log-1');

    final all = await provider.allPoints();

    expect(all.map((p) => p.id).toSet(), {'pt-a', 'pt-b'});
    expect(provider.points.map((p) => p.id).toList(), ['pt-a']);
  });
}
