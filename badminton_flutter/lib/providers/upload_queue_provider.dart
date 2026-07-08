import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/upload_task.dart';
import '../services/analysis_server_settings.dart';
import '../services/database_service.dart';
import '../services/tus_uploader.dart';

/// The mobile upload queue: sqflite-persisted [UploadTask]s driven one at a
/// time through an injected [TusUploader]. Starting is unconditional here;
/// TASK-033 gates the pauseAll/resumeAll seams on WiFi.
class UploadQueueProvider extends ChangeNotifier {
  final TusUploader Function() _uploaderFactory;

  final List<UploadTask> _tasks = [];
  TusUploader? _activeUploader;
  String? _activeId;

  UploadQueueProvider({required TusUploader Function() uploaderFactory})
      : _uploaderFactory = uploaderFactory;

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

  void _startNext() {
    if (_activeId != null) return;
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
