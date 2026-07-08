import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/upload_queue_provider.dart';

/// "Analyse video" entry point for a training session (mobile only):
/// choose the pipeline mode, pick a clip, queue the upload.
class AnalyseVideoButton extends StatelessWidget {
  final String sessionId;

  /// Test seams; production uses the gallery picker and real file size.
  final Future<XFile?> Function()? videoPicker;
  final Future<int> Function(String path)? fileLength;

  const AnalyseVideoButton({
    super.key,
    required this.sessionId,
    this.videoPicker,
    this.fileLength,
  });

  Future<XFile?> _pickVideo() =>
      videoPicker?.call() ??
      ImagePicker().pickVideo(source: ImageSource.gallery);

  Future<int> _length(String path) =>
      fileLength?.call(path) ?? File(path).length();

  Future<void> _enqueue(BuildContext context, String mode) async {
    final queue = context.read<UploadQueueProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final file = await _pickVideo();
    if (file == null) return;
    final error = await queue.enqueue(
      sessionId: sessionId,
      filePath: file.path,
      mode: mode,
      totalBytes: await _length(file.path),
    );
    messenger.showSnackBar(SnackBar(
      content: Text(error ?? 'Video queued — uploads over WiFi'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: const ValueKey('analyseVideoButton'),
      icon: const Icon(Icons.video_camera_back_outlined),
      label: const Text('Analyse video'),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('What should the analysis look at?'),
              ),
              for (final (mode, label, hint) in [
                ('footwork', 'Footwork', 'rear view — recovery to base'),
                ('biomech', 'Biomech', 'side view — joint angles'),
                ('full', 'Full', 'both pipelines'),
              ])
                ListTile(
                  title: Text(label),
                  subtitle: Text(hint),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _enqueue(context, mode);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
