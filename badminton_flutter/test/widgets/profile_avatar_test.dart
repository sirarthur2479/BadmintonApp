import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:badminton_flutter/widgets/profile_avatar.dart';

// 1x1 transparent PNG so FileImage can actually decode in the test.
const List<int> _kTransparentPng = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

void main() {
  testWidgets('renders FileImage for a local path on non-web', (tester) async {
    // Real dart:io futures never complete inside testWidgets' fake-async
    // zone — file setup must run under tester.runAsync.
    final file = await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('avatar_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final f = File('${dir.path}/photo.png');
      await f.writeAsBytes(_kTransparentPng);
      return f;
    });

    await tester.runAsync(
      () => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProfileAvatar(photoPath: file!.path)),
        ),
      ),
    );

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(
      avatar.backgroundImage,
      isA<FileImage>(),
      reason: 'local paths must use FileImage on device, not NetworkImage',
    );
    expect((avatar.backgroundImage as FileImage).file.path, file!.path);
  });

  testWidgets('renders fallback icon when path is null', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ProfileAvatar(photoPath: null))),
    );

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isNull);
    expect(find.byIcon(Icons.person), findsOneWidget);
  });
}
