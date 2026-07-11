import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:badminton_flutter/services/analysis_server_settings.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saves and restores address token and player', () async {
    await AnalysisServerSettings.save(
      address: 'http://192.168.1.50:8001',
      token: 'jwt-abc',
      playerId: 'pl-1',
      playerName: 'Kid One',
    );

    final restored = await AnalysisServerSettings.load();

    expect(restored.address, 'http://192.168.1.50:8001');
    expect(restored.token, 'jwt-abc');
    expect(restored.playerId, 'pl-1');
    expect(restored.playerName, 'Kid One');
  });

  test('load with nothing stored returns empty settings', () async {
    final restored = await AnalysisServerSettings.load();

    expect(restored.address, isNull);
    expect(restored.token, isNull);
    expect(restored.playerId, isNull);
    expect(restored.playerName, isNull);
  });

  test('partial save keeps other fields untouched', () async {
    await AnalysisServerSettings.save(address: 'http://10.0.0.2:8001');
    await AnalysisServerSettings.save(token: 'jwt-xyz');

    final restored = await AnalysisServerSettings.load();

    expect(restored.address, 'http://10.0.0.2:8001');
    expect(restored.token, 'jwt-xyz');
  });

  test('clear removes all analysis keys', () async {
    await AnalysisServerSettings.save(
      address: 'http://192.168.1.50:8001',
      token: 'jwt-abc',
      playerId: 'pl-1',
      playerName: 'Kid One',
    );

    await AnalysisServerSettings.clear();

    final restored = await AnalysisServerSettings.load();
    expect(restored.address, isNull);
    expect(restored.token, isNull);
    expect(restored.playerId, isNull);
    expect(restored.playerName, isNull);

    // Keys are namespaced: clearing must not touch unrelated prefs.
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys().where((k) => k.startsWith('analysis_')),
      isEmpty,
    );
  });
}
