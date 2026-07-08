import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/upload_task.dart';
import '../providers/upload_queue_provider.dart';

/// Fire-and-forget upload state for one session — a slim row, never a
/// blocking spinner. Renders nothing when the session has no uploads.
class UploadStatusRow extends StatelessWidget {
  final String sessionId;

  const UploadStatusRow({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final tasks = context
        .watch<UploadQueueProvider>()
        .tasks
        .where((t) => t.sessionId == sessionId)
        .toList();
    if (tasks.isEmpty) return const SizedBox.shrink();
    final task = tasks.last; // newest attempt wins the row

    final (text, showProgress) = switch (task.status) {
      UploadStatus.pending => ('Upload queued', false),
      UploadStatus.uploading => (
          'Uploading video ${(task.sentBytes / task.totalBytes * 100).round()}%',
          true
        ),
      UploadStatus.paused => ('Upload paused', true),
      UploadStatus.done => ('Video uploaded — analysing on the server', false),
      UploadStatus.failed => ('Upload failed: ${task.error ?? ''}', false),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: Theme.of(context).textTheme.bodySmall),
          if (showProgress)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(
                value: task.totalBytes == 0
                    ? null
                    : task.sentBytes / task.totalBytes,
              ),
            ),
        ],
      ),
    );
  }
}
