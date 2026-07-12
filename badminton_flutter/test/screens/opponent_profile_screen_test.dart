import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:badminton_flutter/models/match_log.dart';
import 'package:badminton_flutter/models/point_record.dart';
import 'package:badminton_flutter/providers/match_log_provider.dart';
import 'package:badminton_flutter/providers/point_record_provider.dart';
import 'package:badminton_flutter/screens/train/opponent_profile_screen.dart';
import 'package:badminton_flutter/services/database_service.dart';

MatchLog _log(String id, {bool isWin = true, DateTime? date, String? videoRef}) =>
    MatchLog(
      id: id,
      date: date ?? DateTime(2026, 7, 12),
      opponent: 'Ken T.',
      isWin: isWin,
      videoRef: videoRef,
    );

var _nextPoint = 0;
PointRecord _point({
  String server = 'player',
  String winner = 'player',
  int? rallyLength,
  String endingType = 'winner',
  String? endingShot,
}) => PointRecord(
  id: 'pt-${_nextPoint++}',
  matchLogId: 'a',
  game: 1,
  indexInGame: _nextPoint,
  server: server,
  winner: winner,
  playerScore: 1,
  opponentScore: 0,
  rallyLength: rallyLength,
  endingType: endingType,
  endingShot: endingShot,
);

Future<void> _pump(
  WidgetTester tester, {
  required List<MatchLog> logs,
  List<PointRecord> points = const [],
  bool? webOverride,
  Widget Function(MatchLog log)? tagScreenBuilder,
}) async {
  await tester.runAsync(() async {
    await DatabaseService.resetForTests();
    await DatabaseService.insertMatchLogs(logs);
    await DatabaseService.insertPointRecords(points);
  });
  final matchLogs = MatchLogProvider();
  final pointRecords = PointRecordProvider();
  await tester.runAsync(matchLogs.loadMatchLogs);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: matchLogs),
        ChangeNotifierProvider.value(value: pointRecords),
      ],
      child: MaterialApp(
        home: OpponentProfileScreen(
          opponentKey: 'ken t.',
          displayName: 'Ken T.',
          webOverride: webOverride,
          tagScreenBuilder: tagScreenBuilder,
        ),
      ),
    ),
  );
  // allPoints() is real async DB work.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbName = 'opponent_profile_screen_test.db';
  });

  testWidgets('profile header shows head to head from logs alone', (
    tester,
  ) async {
    await _pump(
      tester,
      logs: [_log('a'), _log('b', isWin: false), _log('c')],
    );

    expect(find.text('Ken T.'), findsOneWidget);
    expect(find.textContaining('2W – 1L'), findsOneWidget);
    expect(find.textContaining('3 matches'), findsOneWidget);
  });

  testWidgets('profile shows unlock empty state with zero tagged points', (
    tester,
  ) async {
    await _pump(tester, logs: [_log('a')]);

    expect(
      find.textContaining('Tag points from a match video'),
      findsOneWidget,
    );
  });

  testWidgets('profile stat sections render from tagged points', (
    tester,
  ) async {
    await _pump(
      tester,
      logs: [_log('a')],
      points: [
        _point(server: 'player', winner: 'player', rallyLength: 3),
        _point(server: 'player', winner: 'opponent', rallyLength: 12),
        _point(
          server: 'opponent',
          winner: 'opponent',
          endingType: 'winner',
          endingShot: 'smash',
        ),
        _point(server: 'opponent', winner: 'player'),
      ],
    );

    expect(
      find.textContaining('Tag points from a match video'),
      findsNothing,
    );
    // Serve vs receive.
    expect(find.textContaining('On our serve'), findsOneWidget);
    expect(find.textContaining('Receiving'), findsOneWidget);
    // Rally bands section renders tagged bands.
    expect(find.textContaining('short'), findsOneWidget);
    expect(find.textContaining('long'), findsOneWidget);
    // Their finishing shot appears.
    expect(find.textContaining('smash'), findsOneWidget);
    // Points-won headline.
    expect(find.textContaining('4 points tagged'), findsOneWidget);
  });

  testWidgets('match history lists this opponents logs', (tester) async {
    await _pump(
      tester,
      logs: [
        _log('a', date: DateTime(2026, 7, 1)),
        _log('b', isWin: false, date: DateTime(2026, 6, 1)),
      ],
    );

    expect(find.text('WIN'), findsOneWidget);
    expect(find.text('LOSS'), findsOneWidget);
  });

  group('unlock card deep link', () {
    testWidgets('tapping the unlock card opens tagging for the video log', (
      tester,
    ) async {
      await _pump(
        tester,
        logs: [
          _log('old', date: DateTime(2026, 6, 1)),
          _log('with-video', videoRef: '/videos/m.mp4'),
        ],
        webOverride: false,
        tagScreenBuilder: (log) =>
            Scaffold(body: Text('TAG:${log.id}')),
      );

      await tester.tap(find.textContaining('Tag points from'));
      await tester.pumpAndSettle();

      expect(find.text('TAG:with-video'), findsOneWidget);
    });

    testWidgets('unlock card stays passive without a video log', (
      tester,
    ) async {
      await _pump(tester, logs: [_log('a')], webOverride: false);

      expect(
        find.textContaining('add a video to a match log'),
        findsOneWidget,
        reason: 'the card explains the missing step instead of dead-ending',
      );
    });

    testWidgets('unlock card stays passive on web', (tester) async {
      await _pump(
        tester,
        logs: [_log('with-video', videoRef: '/videos/m.mp4')],
        webOverride: true,
      );

      expect(find.textContaining('Tag points from'), findsNothing);
    });
  });
}
