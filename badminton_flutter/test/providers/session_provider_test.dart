import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:badminton_flutter/models/session.dart';
import 'package:badminton_flutter/providers/session_provider.dart';
import 'package:badminton_flutter/services/database_service.dart';

TrainingSession _session(String note, {int day = 1}) => TrainingSession(
      id: const Uuid().v4(),
      date: DateTime(2026, 7, day),
      durationMinutes: 60,
      drills: const ['Footwork'],
      intensity: 3,
      notes: note,
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbName = 'session_provider_test.db';
  });

  setUp(() async {
    await DatabaseService.resetForTests();
  });

  test('refresh() picks up rows inserted behind the provider\'s back',
      () async {
    final provider = SessionProvider();
    await provider.loadSessions();
    expect(provider.sessions, isEmpty);

    // Insert directly at the DB layer — the provider doesn't know.
    await DatabaseService.insertSession(_session('inserted externally'));

    await provider.refresh();
    expect(provider.sessions, hasLength(1),
        reason: 'refresh must reload from the DB even after initial load');
  });

  test('loadSessions() is still a one-shot guard', () async {
    final provider = SessionProvider();
    await provider.loadSessions();

    await DatabaseService.insertSession(_session('inserted externally'));

    await provider.loadSessions();
    expect(provider.sessions, isEmpty,
        reason: 'loadSessions stays guarded; only refresh() reloads');
  });
}
