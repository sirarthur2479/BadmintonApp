import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:badminton_flutter/models/match_log.dart';
import 'package:badminton_flutter/models/point_record.dart';
import 'package:badminton_flutter/providers/point_record_provider.dart';
import 'package:badminton_flutter/screens/train/tag_points_screen.dart';
import 'package:badminton_flutter/services/database_service.dart';

import '../fakes/fake_tagging_video_controller.dart';

final _log = MatchLog(
  id: 'log-1',
  date: DateTime(2026, 7, 12),
  opponent: 'Ken T.',
  isWin: true,
  videoRef: '/videos/league-r3.mp4',
);

PointRecord seedPoint(
  int indexInGame,
  String winner, {
  int game = 1,
  required int playerScore,
  required int opponentScore,
}) => PointRecord(
  id: 'seed-$game-$indexInGame',
  matchLogId: 'log-1',
  game: game,
  indexInGame: indexInGame,
  server: 'player',
  winner: winner,
  playerScore: playerScore,
  opponentScore: opponentScore,
  endingType: 'winner',
);

Future<
  ({FakeTaggingVideoController video, PointRecordProvider provider})
> pumpScreen(WidgetTester tester) async {
  final video = FakeTaggingVideoController(
    videoDuration: const Duration(minutes: 10),
  );
  final provider = PointRecordProvider();
  await tester.runAsync(() async {
    await video.init(_log.videoRef!);
    await provider.loadFor(_log.id);
  });

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(home: TagPointsScreen(log: _log, video: video)),
    ),
  );
  await tester.pump();
  return (video: video, provider: provider);
}

Future<void> chooseFirstServer(WidgetTester tester, {bool player = true}) async {
  await tester.tap(
    find.byKey(ValueKey(player ? 'serveFirstPlayer' : 'serveFirstOpponent')),
  );
  await tester.pumpAndSettle();
}

Future<void> savePoint(
  WidgetTester tester,
  PointRecordProvider provider,
  int expectedCount,
) async {
  await tester.tap(find.byKey(const ValueKey('savePointButton')));
  await tester.runAsync(() async {
    for (
      var i = 0;
      i < 200 && provider.points.length < expectedCount;
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbName = 'tag_points_screen_test.db';
  });

  setUp(() async {
    await DatabaseService.resetForTests();
    await DatabaseService.insertMatchLog(_log);
  });

  testWidgets('first open asks who serves first in game 1', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Who serves first?'), findsOneWidget);
    expect(find.byKey(const ValueKey('serveFirstPlayer')), findsOneWidget);
    expect(find.byKey(const ValueKey('serveFirstOpponent')), findsOneWidget);
    // The tag form is hidden until the choice is made.
    expect(find.byKey(const ValueKey('savePointButton')), findsNothing);
  });

  testWidgets('tagging a point saves derived server, score and timestamp', (
    tester,
  ) async {
    final env = await pumpScreen(tester);
    await chooseFirstServer(tester, player: false);

    env.video.pushPosition(const Duration(seconds: 61, milliseconds: 250));
    await env.video.play();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('winnerPlayer')));
    await tester.pump();
    await tester.tap(find.text('Winner'));
    await tester.pump();
    await savePoint(tester, env.provider, 1);

    final point = env.provider.points.single;
    expect(point.matchLogId, 'log-1');
    expect(point.game, 1);
    expect(point.indexInGame, 1);
    expect(point.server, 'opponent', reason: 'they were chosen to serve first');
    expect(point.winner, 'player');
    expect(point.playerScore, 1);
    expect(point.opponentScore, 0);
    expect(point.endingType, 'winner');
    expect(point.videoTimestampMs, 61250);
    expect(env.video.isPlaying, isFalse, reason: 'saving pauses the video');
  });

  testWidgets('save is disabled until winner and ending type are chosen', (
    tester,
  ) async {
    await pumpScreen(tester);
    await chooseFirstServer(tester);

    ElevatedButton save() => tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('savePointButton')),
    );
    expect(save().onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('winnerPlayer')));
    await tester.pump();
    expect(save().onPressed, isNull, reason: 'ending type still missing');

    await tester.tap(find.text('Winner'));
    await tester.pump();
    expect(save().onPressed, isNotNull);
  });

  testWidgets('form resets after saving a point', (tester) async {
    final env = await pumpScreen(tester);
    await chooseFirstServer(tester);

    await tester.tap(find.byKey(const ValueKey('winnerPlayer')));
    await tester.pump();
    await tester.tap(find.text('Winner'));
    await tester.pump();
    await savePoint(tester, env.provider, 1);

    final save = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('savePointButton')),
    );
    expect(save.onPressed, isNull, reason: 'selections cleared for next point');
    // Header reflects the running score.
    expect(find.textContaining('1–0'), findsOneWidget);
  });
}
