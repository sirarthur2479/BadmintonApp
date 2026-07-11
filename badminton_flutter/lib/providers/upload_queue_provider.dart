import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/upload_task.dart';
import '../services/analysis_server_settings.dart';
import '../services/connectivity_gate.dart';
import '../services/database_service.dart';
import '../services/tus_uploader.dart';

/// The mobile upload queue: sqflite-persisted [UploadTask]s driven one at a
/// time through an injected [TusUploader], and — the owner's non-negotiable
/// constraint — only ever over WiFi: the [ConnectivityGate] pauses the
/// in-flight transfer the instant WiFi drops and resumes it when it returns.
class UploadQueueProvider extends ChangeNotifier {
  final TusUploader Function() _uploaderFactory;
  final ConnectivityGate? _gate;
  StreamSubscription<bool>? _gateSub;

  final List<UploadTask> _tasks = [];
  TusUploader? _activeUploader;
  String? _activeId;

  /// While true (pauseAll), nothing starts — driven by the WiFi gate.
  bool _gatePaused = false;

  UploadQueueProvider({
    required TusUploader Function() uploaderFactory,
    ConnectivityGate? gate,
  })  : _uploaderFactory = uploaderFactory,
        _gate = gate {
    _gateSub = gate?.wifiChanges
        .listen((onWifi) => onWifi ? resumeAll() : pauseAll());
  }

  /// No gate means "not gated" (tests of the raw queue, web never uploads).
  bool get _wifiOk => _gate?.onWifi ?? true;

  /// True when work is queued but held back by the WiFi-only rule.
  bool get waitingForWifi => !_wifiOk;

  @override
  void dispose() {
    _gateSub?.cancel();
    super.dispose();
  }

  List<UploadTask> get tasks => List.unmodifiable(_tasks);

  /// Queues [filePath] for analysis. Returns null on success or a
  /// user-readable error when the analysis server isn't configured.
  Future<String?> enqueue({
    required String sessionId,
    required String filePath,
    required String mode,
    required int totalBytes,
  }) async {
    final settings = await AnalysisServerSettings.load();
    final playerId = settings.playerId;
    if (playerId == null) {
      return 'Connect to the analysis server in settings first';
    }
    final task = UploadTask(
      id: const Uuid().v4(),
      sessionId: sessionId,
      playerId: playerId,
      mode: mode,
      filePath: filePath,
      totalBytes: totalBytes,
    );
    await DatabaseService.insertUploadTask(task);
    _tasks.add(task);
    notifyListeners();
    _startNext();
    return null;
  }

  UploadTask? _byId(String id) =>
      _tasks.cast<UploadTask?>().firstWhere((t) => t!.id == id,
          orElse: () => null);

  Future<void> _update(UploadTask task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index == -1) return;
    _tasks[index] = task;
    await DatabaseService.updateUploadTask(task);
    notifyListeners();
  }

  /// Reloads the persisted queue after an app restart and re-drives
  /// anything unfinished. A row still marked `uploading` means the app was
  /// killed mid-transfer — its tusUrl lets the uploader resume from the
  /// server's confirmed offset, so nothing restarts from zero.
  Future<void> resumePending() async {
    final stored = await DatabaseService.getUploadTasks();
    _tasks
      ..clear()
      ..addAll(stored);
    for (final task in _tasks) {
      if (task.status == UploadStatus.uploading ||
          task.status == UploadStatus.paused) {
        await _update(task.copyWith(status: UploadStatus.pending));
      }
    }
    notifyListeners();
    _startNext();
  }

  /// Stops the in-flight transfer and gates new starts (WiFi lost, TASK-033).
  Future<void> pauseAll() async {
    _gatePaused = true;
    final activeId = _activeId;
    if (activeId != null) {
      await _activeUploader?.pause();
      _clearActive();
      final current = _byId(activeId);
      if (current != null) {
        await _update(current.copyWith(status: UploadStatus.paused));
      }
    }
  }

  /// Lifts the gate and re-drives paused/pending work (WiFi back).
  Future<void> resumeAll() async {
    _gatePaused = false;
    for (final task in List.of(_tasks)) {
      if (task.status == UploadStatus.paused) {
        await _update(task.copyWith(status: UploadStatus.pending));
      }
    }
    _startNext();
  }

  void _startNext() {
    if (_gatePaused || !_wifiOk || _activeId != null) return;
    final next = _tasks
        .cast<UploadTask?>()
        .firstWhere((t) => t!.status == UploadStatus.pending,
            orElse: () => null);
    if (next == null) return;
    _start(next);
  }

  void _start(UploadTask task) {
    _activeId = task.id;
    final uploader = _uploaderFactory();
    _activeUploader = uploader;
    _update(task.copyWith(status: UploadStatus.uploading));

    uploader.upload(
      task,
      onProgress: (sent) {
        final current = _byId(task.id);
        if (current != null) _update(current.copyWith(sentBytes: sent));
      },
      onTusUrl: (url) {
        final current = _byId(task.id);
        if (current != null) _update(current.copyWith(tusUrl: url));
      },
    ).then((_) {
      final current = _byId(task.id);
      if (current != null) {
        _update(current.copyWith(status: UploadStatus.done));
      }
      _clearActive();
      _startNext();
    }).catchError((Object error) {
      final current = _byId(task.id);
      if (current != null && current.status == UploadStatus.uploading) {
        _update(current.copyWith(
          status: UploadStatus.failed,
          error: '$error',
        ));
      }
      _clearActive();
      _startNext();
    });
  }

  void _clearActive() {
    _activeId = null;
    _activeUploader = null;
  }
}
