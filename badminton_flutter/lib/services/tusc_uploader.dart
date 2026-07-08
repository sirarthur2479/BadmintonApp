import 'dart:async';

import 'package:tusc/tusc.dart' as tusc;
import 'package:cross_file/cross_file.dart';

import '../models/upload_task.dart';
import 'analysis_server_settings.dart';
import 'tus_uploader.dart';

/// Production [TusUploader] backed by the `tusc` package (tus 1.0.0
/// Core + Creation — the exact subset TASK-028's server implements).
/// 8 MB chunks: coarse enough to keep per-chunk HTTP overhead low on home
/// WiFi, fine enough that a drop loses at most one chunk of progress.
class TuscUploader implements TusUploader {
  tusc.TusClient? _client;

  @override
  Future<void> upload(
    UploadTask task, {
    required void Function(int sentBytes) onProgress,
    required void Function(String tusUrl) onTusUrl,
  }) async {
    final settings = await AnalysisServerSettings.load();
    final address = settings.address;
    if (address == null) {
      throw StateError('analysis server address not configured');
    }

    final client = tusc.TusClient(
      file: XFile(task.filePath),
      // A fresh upload creates against the collection URL; a resumed one
      // targets the exact upload the server already knows about.
      url: '$address/api/v1/uploads',
      uploadUrl: task.tusUrl,
      cache: tusc.TusPersistentCache(''),
      chunkSize: 8 * 1024 * 1024,
      headers: {'Authorization': 'Bearer ${settings.token}'},
      metadata: {
        // filename is added automatically from the file itself.
        'playerId': task.playerId,
        'sessionId': task.sessionId,
        'mode': task.mode,
      },
    );
    _client = client;

    final done = Completer<void>();
    await client.startUpload(
      onProgress: (count, total, response) {
        if (client.uploadUrl.isNotEmpty) onTusUrl(client.uploadUrl);
        onProgress(count);
      },
      onComplete: (response) {
        if (!done.isCompleted) done.complete();
      },
      onError: (error) {
        if (!done.isCompleted) done.completeError(error);
      },
      onTimeout: () {
        if (!done.isCompleted) {
          done.completeError(TimeoutException('upload timed out'));
        }
      },
    );
    return done.future;
  }

  @override
  Future<void> pause() async {
    await _client?.pauseUpload();
  }
}
