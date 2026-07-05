import 'dart:io';

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

  Future<String> savePhoto(String sourcePath, String sessionId) async {
    return sourcePath; // stub — behaviour driven by photo_store_test.dart
  }

  Future<String?> resolvePath(String stored) async {
    return stored; // stub
  }

  Future<void> deletePhoto(String stored) async {} // stub
}
