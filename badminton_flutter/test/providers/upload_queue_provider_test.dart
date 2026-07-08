import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:badminton_flutter/models/upload_task.dart';
import 'package:badminton_flutter/providers/upload_queue_provider.dart';
import 'package:badminton_flutter/services/database_service.dart';
import 'package:badminton_flutter/services/tus_uploader.dart';

/// A hand-driven uploader: the test decides when progress happens, when the
/// transfer completes, and when it fails.
class FakeTusUploader implements TusUploader {
  final _completer = Completer<void>();
  UploadTask? task;
  void Function(int sentBytes)? onProgress;
  void Function(String tusUrl)? onTusUrl;
  int pauseCalls = 0;

  @override
  Future<void> upload(
    UploadTask task, {
    required void Function(int sentBytes) onProgress,
    required void Function(String tusUrl) onTusUrl,
  }) {
    this.task = task;
    this.onProgress = onProgress;
    this.onTusUrl = onTusUrl;
    return _completer.future;
  }

  @override
  Future<void> pause() async {
    pauseCalls += 1;
  }

  void emitProgress(int sent) => onProgress!(sent);
  void emitTusUrl(String url) => onTusUrl!(url);
  void complete() => _completer.complete();
  void fail(Object error) => _completer.completeError(error);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final created = <FakeTusUploader>[];

  UploadQueueProvider makeProvider() => UploadQueueProvider(
        uploaderFactory: () {
          final uploader = FakeTusUploader();
          created.add(uploader);
          return uploader;
        },
      );

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    created.clear();
    SharedPreferences.setMockInitialValues({
      'analysis_server_address': 'http://192.168.1.50:8001',
      'analysis_token': 'jwt-lan',
      'analysis_player_id': 'pl-1',
      'analysis_player_name': 'Kid One',
    });
    DatabaseService.dbName = 'upload_queue_provider_test.db';
    await DatabaseService.resetForTests();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('enqueue persists a pending row with the configured player', () async {
    final provider = makeProvider();

    await provider.enqueue(
      sessionId: 'sess-1',
      filePath: '/videos/clip.mp4',
      mode: 'footwork',
      totalBytes: 1000,
    );

    final stored = (await DatabaseService.getUploadTasks()).single;
    expect(stored.playerId, 'pl-1');
    expect(stored.sessionId, 'sess-1');
    expect(stored.mode, 'footwork');
    expect(provider.tasks.single.id, stored.id);
  });

  test('enqueue without a configured server fails readably and stores nothing',
      () async {
    SharedPreferences.setMockInitialValues({});
    final provider = makeProvider();

    final error = await provider.enqueue(
      sessionId: 'sess-1',
      filePath: '/videos/clip.mp4',
      mode: 'footwork',
      totalBytes: 1000,
    );

    expect(error, isNotNull);
    expect(await DatabaseService.getUploadTasks(), isEmpty);
  });

  test('enqueue starts the upload; progress lands in sentBytes and the db',
      () async {
    final provider = makeProvider();
    await provider.enqueue(
      sessionId: 'sess-1',
      filePath: '/videos/clip.mp4',
      mode: 'footwork',
      totalBytes: 1000,
    );
    await settle();

    expect(created, hasLength(1));
    expect(provider.tasks.single.status, UploadStatus.uploading);

    created.single.emitTusUrl('http://server/api/v1/uploads/u-1');
    created.single.emitProgress(400);
    await settle();

    expect(provider.tasks.single.sentBytes, 400);
    final stored = (await DatabaseService.getUploadTasks()).single;
    expect(stored.sentBytes, 400);
    expect(stored.tusUrl, 'http://server/api/v1/uploads/u-1');
  });

  test('completion marks done', () async {
    final provider = makeProvider();
    await provider.enqueue(
      sessionId: 'sess-1',
      filePath: '/videos/clip.mp4',
      mode: 'footwork',
      totalBytes: 1000,
    );
    await settle();

    created.single.emitProgress(1000);
    created.single.complete();
    await settle();

    expect(provider.tasks.single.status, UploadStatus.done);
    final stored = (await DatabaseService.getUploadTasks()).single;
    expect(stored.status, UploadStatus.done);
    expect(stored.sentBytes, 1000);
  });

  test('uploader error marks failed with the message', () async {
    final provider = makeProvider();
    await provider.enqueue(
      sessionId: 'sess-1',
      filePath: '/videos/clip.mp4',
      mode: 'footwork',
      totalBytes: 1000,
    );
    await settle();

    created.single.fail(Exception('server unreachable'));
    await settle();

    expect(provider.tasks.single.status, UploadStatus.failed);
    expect(provider.tasks.single.error, contains('server unreachable'));
    final stored = (await DatabaseService.getUploadTasks()).single;
    expect(stored.status, UploadStatus.failed);
  });

  test('only one upload runs at a time; the next starts on completion',
      () async {
    final provider = makeProvider();
    await provider.enqueue(
      sessionId: 'sess-1',
      filePath: '/videos/a.mp4',
      mode: 'footwork',
      totalBytes: 10,
    );
    await provider.enqueue(
      sessionId: 'sess-2',
      filePath: '/videos/b.mp4',
      mode: 'biomech',
      totalBytes: 20,
    );
    await settle();

    expect(created, hasLength(1), reason: 'second upload must wait');
    expect(
      provider.tasks.where((t) => t.status == UploadStatus.uploading),
      hasLength(1),
    );

    created.single.complete();
    await settle();
    await settle();

    expect(created, hasLength(2), reason: 'queue advances after completion');
    expect(created.last.task!.filePath, '/videos/b.mp4');
  });
}
