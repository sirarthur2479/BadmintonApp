import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:badminton_flutter/data/sample_sessions_seed.dart';
import 'package:badminton_flutter/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseService.resetForTests();
  });

  test('seeds when flag unset and db empty', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final seeded = await seedSampleDataIfNeeded(prefs);

    expect(seeded, isTrue);
    expect(await DatabaseService.hasAnySessions(), isTrue);
  });

  test('does not seed when flag already set, even if db is empty', () async {
    // The user has deleted the demo data: flag set, DB empty.
    SharedPreferences.setMockInitialValues({kSampleDataSeededKey: true});
    final prefs = await SharedPreferences.getInstance();

    final seeded = await seedSampleDataIfNeeded(prefs);

    expect(seeded, isFalse);
    expect(await DatabaseService.hasAnySessions(), isFalse,
        reason: 'deleted demo data must stay deleted across restarts');
  });

  test('sets flag after seeding', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await seedSampleDataIfNeeded(prefs);

    expect(prefs.getBool(kSampleDataSeededKey), isTrue);
  });
}
