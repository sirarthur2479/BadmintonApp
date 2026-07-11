import 'package:flutter_test/flutter_test.dart';

import 'package:badminton_flutter/models/upload_task.dart';

void main() {
  test('upload task map round trip', () {
    const task = UploadTask(
      id: 'ut-1',
      sessionId: 'sess-1',
      playerId: 'pl-1',
      mode: 'footwork',
      filePath: '/videos/clip.mp4',
      totalBytes: 1024,
      sentBytes: 512,
      status: UploadStatus.uploading,
      tusUrl: 'http://192.168.1.50:8001/api/v1/uploads/u-9',
      error: null,
    );

    final restored = UploadTask.fromMap(task.toMap());

    expect(restored.id, task.id);
    expect(restored.sessionId, task.sessionId);
    expect(restored.playerId, task.playerId);
    expect(restored.mode, task.mode);
    expect(restored.filePath, task.filePath);
    expect(restored.totalBytes, 1024);
    expect(restored.sentBytes, 512);
    expect(restored.status, UploadStatus.uploading);
    expect(restored.tusUrl, task.tusUrl);
    expect(restored.error, isNull);
  });

  test('unknown status in a stored row degrades to failed, not a crash', () {
    final map = const UploadTask(
      id: 'ut-2',
      sessionId: 's',
      playerId: 'p',
      mode: 'biomech',
      filePath: '/v.mp4',
      totalBytes: 1,
    ).toMap()
      ..['status'] = 'someday-new-status';

    expect(UploadTask.fromMap(map).status, UploadStatus.failed);
  });

  test('copyWith replaces only what is passed', () {
    const task = UploadTask(
      id: 'ut-3',
      sessionId: 's',
      playerId: 'p',
      mode: 'full',
      filePath: '/v.mp4',
      totalBytes: 100,
    );

    final updated = task.copyWith(
      sentBytes: 40,
      status: UploadStatus.uploading,
    );

    expect(updated.sentBytes, 40);
    expect(updated.status, UploadStatus.uploading);
    expect(updated.id, 'ut-3');
    expect(updated.totalBytes, 100);
  });
}
