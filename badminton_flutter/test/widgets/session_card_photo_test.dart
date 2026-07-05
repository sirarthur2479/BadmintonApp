import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:badminton_flutter/models/session.dart';
import 'package:badminton_flutter/services/photo_store.dart';
import 'package:badminton_flutter/widgets/session_card.dart';

const List<int> _kTransparentPng = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

TrainingSession _session({String? photoPath}) => TrainingSession(
      id: const Uuid().v4(),
      date: DateTime(2026, 7, 1),
      durationMinutes: 60,
      drills: const ['Footwork'],
      intensity: 3,
      photoPath: photoPath,
    );

void main() {
  testWidgets('card shows thumbnail when photoPath resolves to a file',
      (tester) async {
    final stored = await tester.runAsync(() async {
      final baseDir = await Directory.systemTemp.createTemp('card_photo');
      addTearDown(() {
        PhotoStore.instance = PhotoStore();
        baseDir.deleteSync(recursive: true);
      });
      PhotoStore.instance = PhotoStore(baseDirProvider: () async => baseDir);

      final src = File('${baseDir.path}/src.png');
      await src.writeAsBytes(_kTransparentPng);
      return PhotoStore.instance.savePhoto(src.path, 'sess-1');
    });

    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SessionCard(session: _session(photoPath: stored))),
      ));
      // Let resolvePath and image IO complete outside the fake-async zone.
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(find.byType(Image), findsOneWidget,
        reason: 'a session with a photo must show a thumbnail');
  });

  testWidgets('card renders without photo section when photoPath is null',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SessionCard(session: _session())),
    ));

    expect(find.byType(Image), findsNothing);
  });
}
