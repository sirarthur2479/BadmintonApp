import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:badminton_flutter/models/upload_task.dart';
import 'package:badminton_flutter/providers/upload_queue_provider.dart';
import 'package:badminton_flutter/services/connectivity_gate.dart';
import 'package:badminton_flutter/services/database_service.dart';
import 'package:badminton_flutter/services/tus_uploader.dart';
import 'package:badminton_flutter/widgets/analyse_video_button.dart';
import 'package:badminton_flutter/widgets/upload_status_row.dart';

class _NeverFinishingUploader implements TusUploader {
  @override
  Future<void> upload(
    UploadTask task, {
    required void Function(int sentBytes) onProgress,
    required void Function(String tusUrl) onTusUrl,
  }) =>
      Completer<void>().future;

  @override
  Future<void> pause() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'analysis_server_address': 'http://192.168.1.50:8001',
      'analysis_token': 'jwt-lan',
      'analysis_player_id': 'pl-1',
      'analysis_player_name': 'Kid One',
    });
    DatabaseService.dbName = 'upload_ui_test.db';
    await DatabaseService.resetForTests();
  });

  Widget wrap(UploadQueueProvider provider, Widget child) =>
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(home: Scaffold(body: child)),
      );

  testWidgets('analyse video action enqueues with session id and chosen mode',
      (tester) async {
    final provider = UploadQueueProvider(
      uploaderFactory: _NeverFinishingUploader.new,
    );
    await tester.pumpWidget(wrap(
      provider,
      AnalyseVideoButton(
        sessionId: 'sess-42',
        videoPicker: () async => XFile('/videos/clip.mp4'),
        fileLength: (path) async => 4096,
      ),
    ));

    await tester.tap(find.byKey(const ValueKey('analyseVideoButton')));
    await tester.pumpAndSettle();

    // Mode chooser sheet.
    expect(find.text('Footwork'), findsOneWidget);
    expect(find.text('Biomech'), findsOneWidget);
    expect(find.text('Full'), findsOneWidget);

    await tester.tap(find.text('Biomech'));
    await tester.pumpAndSettle();
    // The enqueue path crosses the sqflite ffi isolate — real async that the
    // fake-async test zone never advances on its own.
    await tester.runAsync(() async {
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (provider.tasks.isEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });

    final task = provider.tasks.single;
    expect(task.sessionId, 'sess-42');
    expect(task.mode, 'biomech');
    expect(task.filePath, '/videos/clip.mp4');
    expect(task.totalBytes, 4096);
  });

  testWidgets('cancelled picker enqueues nothing', (tester) async {
    final provider = UploadQueueProvider(
      uploaderFactory: _NeverFinishingUploader.new,
    );
    await tester.pumpWidget(wrap(
      provider,
      AnalyseVideoButton(
        sessionId: 'sess-42',
        videoPicker: () async => null,
        fileLength: (path) async => fail('must not stat without a file'),
      ),
    ));

    await tester.tap(find.byKey(const ValueKey('analyseVideoButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Footwork'));
    await tester.pumpAndSettle();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));

    expect(provider.tasks, isEmpty);
  });

  testWidgets('queue row shows uploading progress for its session',
      (tester) async {
    final provider = UploadQueueProvider(
      uploaderFactory: _NeverFinishingUploader.new,
    );
    await tester.runAsync(() async {
      await DatabaseService.insertUploadTask(const UploadTask(
        id: 'ut-1',
        sessionId: 'sess-42',
        playerId: 'pl-1',
        mode: 'footwork',
        filePath: '/videos/clip.mp4',
        totalBytes: 1000,
        sentBytes: 400,
        status: UploadStatus.uploading,
      ));
      await provider.resumePending();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    // resumePending re-drives it; it stays 'uploading' with 400 sent.
    await tester.pumpWidget(wrap(
      provider,
      const UploadStatusRow(sessionId: 'sess-42'),
    ));
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('Uploading'), findsOneWidget);
  });

  testWidgets('queue row shows failure message and nothing for other sessions',
      (tester) async {
    final provider = UploadQueueProvider(
      uploaderFactory: _NeverFinishingUploader.new,
    );
    await tester.runAsync(() async {
      await DatabaseService.insertUploadTask(const UploadTask(
        id: 'ut-2',
        sessionId: 'sess-42',
        playerId: 'pl-1',
        mode: 'footwork',
        filePath: '/videos/clip.mp4',
        totalBytes: 1000,
        status: UploadStatus.failed,
        error: 'server unreachable',
      ));
      await provider.resumePending();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpWidget(wrap(
      provider,
      const Column(
        children: [
          UploadStatusRow(sessionId: 'sess-42'),
          UploadStatusRow(sessionId: 'sess-other'),
        ],
      ),
    ));
    await tester.pump();

    expect(find.textContaining('server unreachable'), findsOneWidget);
    // The unrelated session renders nothing.
    expect(find.textContaining('Upload'), findsOneWidget);
  });

  testWidgets('queue row shows waiting-for-wifi when gated off wifi',
      (tester) async {
    final gate = ConnectivityGate(
      stream: const Stream<List<ConnectivityResult>>.empty(),
      check: () async => const [ConnectivityResult.mobile],
    );
    await gate.initialise();
    final provider = UploadQueueProvider(
      uploaderFactory: _NeverFinishingUploader.new,
      gate: gate,
    );
    await tester.runAsync(() async {
      await DatabaseService.insertUploadTask(const UploadTask(
        id: 'ut-3',
        sessionId: 'sess-42',
        playerId: 'pl-1',
        mode: 'footwork',
        filePath: '/videos/clip.mp4',
        totalBytes: 1000,
        status: UploadStatus.pending,
      ));
      await provider.resumePending();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpWidget(wrap(
      provider,
      const UploadStatusRow(sessionId: 'sess-42'),
    ));
    await tester.pump();

    expect(find.textContaining('Waiting for WiFi'), findsOneWidget);
  });
}
