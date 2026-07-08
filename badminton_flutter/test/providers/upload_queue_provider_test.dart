import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:badminton_flutter/models/upload_task.dart';
import 'package:badminton_flutter/providers/upload_queue_provider.dart';
import 'package:badminton_flutter/services/connectivity_gate.dart';
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

  /// The queue advances through real async DB writes (ffi isolate), so
  /// zero-delay settles aren't always enough — poll, then let the last
  /// write flush before the test ends (setUp closes the db).
  Future<void> waitFor(bool Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (!condition() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

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
    await waitFor(() => created.length == 2);

    expect(created.last.task!.filePath, '/videos/b.mp4');
    expect(
      provider.tasks.where((t) => t.status == UploadStatus.done),
      hasLength(1),
    );
  });

  // --- Slice 3: restart recovery + pause/resume seams ---

  test('resumePending re-drives interrupted uploads with their tus url',
      () async {
    // Rows left behind by a killed app: one mid-transfer, one waiting.
    await DatabaseService.insertUploadTask(const UploadTask(
      id: 'ut-killed',
      sessionId: 'sess-1',
      playerId: 'pl-1',
      mode: 'footwork',
      filePath: '/videos/a.mp4',
      totalBytes: 1000,
      sentBytes: 400,
      status: UploadStatus.uploading,
      tusUrl: 'http://server/api/v1/uploads/u-1',
    ));
    await DatabaseService.insertUploadTask(const UploadTask(
      id: 'ut-waiting',
      sessionId: 'sess-2',
      playerId: 'pl-1',
      mode: 'biomech',
      filePath: '/videos/b.mp4',
      totalBytes: 500,
    ));

    final provider = makeProvider();
    await provider.resumePending();
    await settle();

    expect(provider.tasks, hasLength(2));
    expect(created, hasLength(1), reason: 'still one at a time');
    // The interrupted one goes first and carries its resume URL.
    expect(created.single.task!.id, 'ut-killed');
    expect(
      created.single.task!.tusUrl,
      'http://server/api/v1/uploads/u-1',
    );
  });

  test('resumePending skips done and failed rows', () async {
    await DatabaseService.insertUploadTask(const UploadTask(
      id: 'ut-done',
      sessionId: 's',
      playerId: 'pl-1',
      mode: 'footwork',
      filePath: '/v.mp4',
      totalBytes: 1,
      status: UploadStatus.done,
    ));
    await DatabaseService.insertUploadTask(const UploadTask(
      id: 'ut-failed',
      sessionId: 's',
      playerId: 'pl-1',
      mode: 'footwork',
      filePath: '/v.mp4',
      totalBytes: 1,
      status: UploadStatus.failed,
      error: 'boom',
    ));

    final provider = makeProvider();
    await provider.resumePending();
    await settle();

    expect(created, isEmpty);
    expect(provider.tasks, hasLength(2), reason: 'still listed for the UI');
  });

  test('pauseAll pauses the active upload and gates new starts', () async {
    final provider = makeProvider();
    await provider.enqueue(
      sessionId: 'sess-1',
      filePath: '/videos/a.mp4',
      mode: 'footwork',
      totalBytes: 1000,
    );
    await settle();

    await provider.pauseAll();

    expect(created.single.pauseCalls, 1);
    expect(provider.tasks.single.status, UploadStatus.paused);
    final stored = (await DatabaseService.getUploadTasks()).single;
    expect(stored.status, UploadStatus.paused);

    // While paused, a new enqueue queues but must not start.
    await provider.enqueue(
      sessionId: 'sess-2',
      filePath: '/videos/b.mp4',
      mode: 'biomech',
      totalBytes: 10,
    );
    await settle();
    expect(created, hasLength(1));
  });

  test('resumeAll restarts the paused upload', () async {
    final provider = makeProvider();
    await provider.enqueue(
      sessionId: 'sess-1',
      filePath: '/videos/a.mp4',
      mode: 'footwork',
      totalBytes: 1000,
    );
    await settle();
    created.single.emitTusUrl('http://server/api/v1/uploads/u-1');
    await settle();
    await provider.pauseAll();

    await provider.resumeAll();
    await settle();

    expect(created, hasLength(2));
    expect(created.last.task!.id, provider.tasks.single.id);
    expect(created.last.task!.tusUrl, 'http://server/api/v1/uploads/u-1',
        reason: 'resume must re-use the server upload, not start over');
    expect(provider.tasks.single.status, UploadStatus.uploading);
  });

  // --- TASK-033: WiFi-only gating ---

  group('wifi gate', () {
    late StreamController<List<ConnectivityResult>> connectivity;
    List<ConnectivityResult> current = const [ConnectivityResult.wifi];

    setUp(() {
      connectivity = StreamController<List<ConnectivityResult>>.broadcast();
      current = const [ConnectivityResult.wifi];
    });

    Future<UploadQueueProvider> gatedProvider() async {
      final gate = ConnectivityGate(
        stream: connectivity.stream,
        check: () async => current,
      );
      await gate.initialise();
      return UploadQueueProvider(
        uploaderFactory: () {
          final uploader = FakeTusUploader();
          created.add(uploader);
          return uploader;
        },
        gate: gate,
      );
    }

    test('enqueue off wifi leaves the row pending and starts nothing',
        () async {
      current = const [ConnectivityResult.mobile, ConnectivityResult.vpn];
      final provider = await gatedProvider();

      await provider.enqueue(
        sessionId: 'sess-1',
        filePath: '/videos/a.mp4',
        mode: 'footwork',
        totalBytes: 100,
      );
      await settle();

      expect(created, isEmpty, reason: 'cellular must never carry a byte');
      expect(provider.tasks.single.status, UploadStatus.pending);
    });

    test('wifi loss pauses the inflight upload immediately', () async {
      final provider = await gatedProvider();
      await provider.enqueue(
        sessionId: 'sess-1',
        filePath: '/videos/a.mp4',
        mode: 'footwork',
        totalBytes: 100,
      );
      await settle();
      expect(provider.tasks.single.status, UploadStatus.uploading);

      connectivity.add(const [ConnectivityResult.mobile]);
      await waitFor(
          () => provider.tasks.single.status == UploadStatus.paused);

      expect(created.single.pauseCalls, 1);
    });

    test('wifi return resumes paused work and starts pending rows', () async {
      current = const [ConnectivityResult.mobile];
      final provider = await gatedProvider();
      await provider.enqueue(
        sessionId: 'sess-1',
        filePath: '/videos/a.mp4',
        mode: 'footwork',
        totalBytes: 100,
      );
      await settle();
      expect(created, isEmpty);

      connectivity.add(const [ConnectivityResult.wifi]);
      await waitFor(() => created.length == 1);

      expect(provider.tasks.single.status, UploadStatus.uploading);
    });

    test('startup resumePending respects current connectivity', () async {
      await DatabaseService.insertUploadTask(const UploadTask(
        id: 'ut-1',
        sessionId: 's',
        playerId: 'pl-1',
        mode: 'footwork',
        filePath: '/v.mp4',
        totalBytes: 10,
        status: UploadStatus.uploading,
      ));
      current = const [ConnectivityResult.none];
      final provider = await gatedProvider();

      await provider.resumePending();
      await settle();

      expect(created, isEmpty);
      expect(provider.tasks.single.status, UploadStatus.pending);
    });
  });
}
