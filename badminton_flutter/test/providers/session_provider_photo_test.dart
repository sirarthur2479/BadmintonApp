import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:badminton_flutter/models/session.dart';
import 'package:badminton_flutter/providers/session_provider.dart';
import 'package:badminton_flutter/services/database_service.dart';
import 'package:badminton_flutter/services/photo_store.dart';

void main() {
  late Directory baseDir;
  late Directory sourceDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbName = 'session_provider_photo_test.db';
  });

  setUp(() async {
    await DatabaseService.resetForTests();
    baseDir = await Directory.systemTemp.createTemp('photo_base');
    sourceDir = await Directory.systemTemp.createTemp('photo_src');
    PhotoStore.instance = PhotoStore(baseDirProvider: () async => baseDir);
  });

  tearDown(() {
    PhotoStore.instance = PhotoStore();
    baseDir.deleteSync(recursive: true);
    sourceDir.deleteSync(recursive: true);
  });

  test('deleting a session deletes its stored photo file', () async {
    final source = File('${sourceDir.path}/picked.jpg');
    await source.writeAsBytes([1, 2, 3]);

    final id = const Uuid().v4();
    final stored = await PhotoStore.instance.savePhoto(source.path, id);

    final provider = SessionProvider();
    await provider.addSession(TrainingSession(
      id: id,
      date: DateTime(2026, 7, 1),
      durationMinutes: 60,
      drills: const ['Footwork'],
      intensity: 3,
      photoPath: stored,
    ));

    await provider.deleteSession(id);

    expect(await PhotoStore.instance.resolvePath(stored), isNull,
        reason: 'deleting a session must not orphan its photo file');
  });
}
