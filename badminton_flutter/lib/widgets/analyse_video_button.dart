import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/upload_queue_provider.dart';

/// Where the video comes from: record with the camera right now, pick from
/// the phone's photo library, or browse local files (Files app / storage).
enum VideoSource { camera, gallery, files }

/// "Analyse video" entry point for a training session (mobile only):
/// choose the pipeline mode, choose the video source, queue the upload.
class AnalyseVideoButton extends StatelessWidget {
  final String sessionId;

  /// Test seams; production dispatches on [VideoSource] and reads the real
  /// file size.
  final Future<XFile?> Function(VideoSource source)? videoPicker;
  final Future<int> Function(String path)? fileLength;

  const AnalyseVideoButton({
    super.key,
    required this.sessionId,
    this.videoPicker,
    this.fileLength,
  });

  Future<XFile?> _pickVideo(VideoSource source) async {
    if (videoPicker != null) return videoPicker!(source);
    switch (source) {
      case VideoSource.camera:
        return ImagePicker().pickVideo(source: ImageSource.camera);
      case VideoSource.gallery:
        return ImagePicker().pickVideo(source: ImageSource.gallery);
      case VideoSource.files:
        final result = await FilePicker.pickFiles(type: FileType.video);
        final path = result?.files.single.path;
        return path == null ? null : XFile(path);
    }
  }

  Future<int> _length(String path) =>
      fileLength?.call(path) ?? File(path).length();

  Future<void> _enqueue(
    BuildContext context,
    String mode,
    VideoSource source,
  ) async {
    final queue = context.read<UploadQueueProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final file = await _pickVideo(source);
    if (file == null) return; // picker/recording cancelled
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

  Future<void> _chooseSource(BuildContext context, String mode) async {
    final source = await showModalBottomSheet<VideoSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Where is the video?'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Record video'),
              subtitle: const Text('open the camera now'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(VideoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photo library'),
              subtitle: const Text('recorded earlier on this phone'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(VideoSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Choose a file'),
              subtitle: const Text('Files app / local storage'),
              onTap: () => Navigator.of(sheetContext).pop(VideoSource.files),
            ),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return;
    await _enqueue(context, mode, source);
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
                    _chooseSource(context, mode);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
