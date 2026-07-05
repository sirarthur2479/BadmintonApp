import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Stores session photos under the app documents directory so they survive
/// iOS cache purges; paths are stored relative so they survive app-container
/// moves between updates.
class PhotoStore {
  PhotoStore({Future<Directory> Function()? baseDirProvider})
      : _baseDirProvider = baseDirProvider ?? getApplicationDocumentsDirectory;

  /// Swap in tests to point at a temp dir.
  static PhotoStore instance = PhotoStore();

  final Future<Directory> Function() _baseDirProvider;

  static const _subdir = 'session_photos';

  /// Copies [sourcePath] into the photo folder; returns the RELATIVE path
  /// to store in the DB.
  Future<String> savePhoto(String sourcePath, String sessionId) async {
    final base = await _baseDirProvider();
    final ext = p.extension(sourcePath);
    final relative = p.posix.join(_subdir, '$sessionId$ext');
    final target = File(p.join(base.path, _subdir, '$sessionId$ext'));
    await target.parent.create(recursive: true);
    await File(sourcePath).copy(target.path);
    return relative;
  }

  /// Resolves a stored path to an absolute one, or null when the file is
  /// gone. Absolute inputs are legacy rows — passed through when they still
  /// exist.
  Future<String?> resolvePath(String stored) async {
    final absolute = p.isAbsolute(stored)
        ? stored
        : p.join((await _baseDirProvider()).path, stored);
    return await File(absolute).exists() ? absolute : null;
  }

  Future<void> deletePhoto(String stored) async {
    final absolute = await resolvePath(stored);
    if (absolute != null) await File(absolute).delete();
  }
}
