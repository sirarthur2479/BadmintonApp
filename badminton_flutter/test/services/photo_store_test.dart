import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:badminton_flutter/services/photo_store.dart';

void main() {
  late Directory baseDir;
  late Directory sourceDir;
  late PhotoStore store;

  setUp(() async {
    baseDir = await Directory.systemTemp.createTemp('photo_store_base');
    sourceDir = await Directory.systemTemp.createTemp('photo_store_src');
    store = PhotoStore(baseDirProvider: () async => baseDir);
  });

  tearDown(() {
    baseDir.deleteSync(recursive: true);
    sourceDir.deleteSync(recursive: true);
  });

  Future<File> makeSource(String name) async {
    final f = File('${sourceDir.path}/$name');
    await f.writeAsBytes([1, 2, 3]);
    return f;
  }

  test('savePhoto copies into session_photos and returns relative path',
      () async {
    final source = await makeSource('picked.jpg');

    final stored = await store.savePhoto(source.path, 'session-abc');

    expect(stored, 'session_photos/session-abc.jpg');
    final copied = File('${baseDir.path}/$stored');
    expect(await copied.exists(), isTrue);
    expect(await copied.readAsBytes(), [1, 2, 3]);
  });

  test('resolvePath returns absolute file under documents dir for relative input',
      () async {
    final source = await makeSource('picked.jpg');
    final stored = await store.savePhoto(source.path, 'session-abc');

    final resolved = await store.resolvePath(stored);

    expect(resolved, '${baseDir.path}/session_photos/session-abc.jpg');
    expect(await File(resolved!).exists(), isTrue);
  });

  test('resolvePath passes through existing absolute legacy paths', () async {
    final legacy = await makeSource('legacy.jpg');

    expect(await store.resolvePath(legacy.path), legacy.path);
  });

  test('resolvePath returns null for missing files', () async {
    expect(await store.resolvePath('session_photos/nope.jpg'), isNull);
    expect(await store.resolvePath('${sourceDir.path}/nope.jpg'), isNull);
  });

  test('deletePhoto removes the file and tolerates missing files', () async {
    final source = await makeSource('picked.jpg');
    final stored = await store.savePhoto(source.path, 'session-abc');

    await store.deletePhoto(stored);
    expect(await store.resolvePath(stored), isNull);

    // Second delete must not throw.
    await store.deletePhoto(stored);
  });
}
