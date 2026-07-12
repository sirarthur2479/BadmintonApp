import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:badminton_flutter/models/match_log.dart';
import 'package:badminton_flutter/models/point_record.dart';
import 'package:badminton_flutter/services/database_service.dart';

MatchLog _log(String id) => MatchLog(
  id: id,
  date: DateTime(2026, 7, 12),
  opponent: 'Ken T.',
  isWin: true,
  videoRef: '/videos/league-r3.mp4',
);

PointRecord _point(
  String id, {
  String matchLogId = 'log-1',
  int game = 1,
  int indexInGame = 1,
  String winner = 'player',
}) => PointRecord(
  id: id,
  matchLogId: matchLogId,
  game: game,
  indexInGame: indexInGame,
  server: 'player',
  winner: winner,
  playerScore: 1,
  opponentScore: 0,
  endingType: 'winner',
);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbName = 'point_record_db_test.db';
  });

  setUp(() async {
    await DatabaseService.resetForTests();
    await DatabaseService.insertMatchLog(_log('log-1'));
  });

  test('point records insert and read back ordered by game then index', () async {
    await DatabaseService.insertPointRecord(
      _point('pt-g2-1', game: 2, indexInGame: 1),
    );
    await DatabaseService.insertPointRecord(
      _point('pt-g1-2', game: 1, indexInGame: 2),
    );
    await DatabaseService.insertPointRecord(
      _point('pt-g1-1', game: 1, indexInGame: 1),
    );

    final points = await DatabaseService.getPointRecords('log-1');

    expect(points.map((p) => p.id).toList(), [
      'pt-g1-1',
      'pt-g1-2',
      'pt-g2-1',
    ]);
  });

  test('insertPointRecord with same id replaces the row', () async {
    await DatabaseService.insertPointRecord(_point('pt-1'));
    await DatabaseService.insertPointRecord(_point('pt-1', winner: 'opponent'));

    final points = await DatabaseService.getPointRecords('log-1');

    expect(points, hasLength(1));
    expect(points.single.winner, 'opponent');
  });

  test('batch insert upserts all rows', () async {
    await DatabaseService.insertPointRecord(_point('pt-1'));

    await DatabaseService.insertPointRecords([
      _point('pt-1', winner: 'opponent'),
      _point('pt-2', indexInGame: 2),
    ]);

    final points = await DatabaseService.getPointRecords('log-1');
    expect(points.map((p) => p.id).toList(), ['pt-1', 'pt-2']);
    expect(points.first.winner, 'opponent', reason: 'batch upserts');
  });

  test('clearPointRecords removes only that logs points', () async {
    await DatabaseService.insertMatchLog(_log('log-2'));
    await DatabaseService.insertPointRecord(_point('pt-1'));
    await DatabaseService.insertPointRecord(
      _point('pt-other', matchLogId: 'log-2'),
    );

    await DatabaseService.clearPointRecords('log-1');

    expect(await DatabaseService.getPointRecords('log-1'), isEmpty);
    final kept = await DatabaseService.getPointRecords('log-2');
    expect(kept.map((p) => p.id).toList(), ['pt-other']);
  });

  test('deletePointRecord removes a single point', () async {
    await DatabaseService.insertPointRecord(_point('pt-1'));
    await DatabaseService.insertPointRecord(_point('pt-2', indexInGame: 2));

    await DatabaseService.deletePointRecord('log-1', 'pt-1');

    final points = await DatabaseService.getPointRecords('log-1');
    expect(points.map((p) => p.id).toList(), ['pt-2']);
  });

  test('getAllPointRecords spans match logs', () async {
    await DatabaseService.insertMatchLog(_log('log-2'));
    await DatabaseService.insertPointRecord(_point('pt-a'));
    await DatabaseService.insertPointRecord(
      _point('pt-b', matchLogId: 'log-2'),
    );

    final all = await DatabaseService.getAllPointRecords();

    expect(all.map((p) => p.id).toSet(), {'pt-a', 'pt-b'});
  });

  test('deleting a match log cascades its point records', () async {
    await DatabaseService.insertPointRecord(_point('pt-1'));

    await DatabaseService.deleteMatchLog('log-1');

    expect(await DatabaseService.getAllPointRecords(), isEmpty);
  });

  test('shots survive the sqflite round-trip', () async {
    final withShots = _point('pt-1').copyWith(
      shots: const [
        {'shotType': 'smash', 'side': 'player', 'timestampMs': 3200},
      ],
    );

    await DatabaseService.insertPointRecord(withShots);

    final restored = await DatabaseService.getPointRecords('log-1');
    expect(restored.single.shots, withShots.shots);
  });
}
