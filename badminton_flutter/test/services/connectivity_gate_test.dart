import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:badminton_flutter/services/connectivity_gate.dart';

void main() {
  test('reports wifi when the list contains wifi among others', () async {
    final source = StreamController<List<ConnectivityResult>>.broadcast();
    final gate = ConnectivityGate(
      stream: source.stream,
      check: () async => [ConnectivityResult.wifi, ConnectivityResult.vpn],
    );
    await gate.initialise();

    expect(gate.onWifi, isTrue);
  });

  test('mobile plus vpn without wifi is NOT wifi', () async {
    final source = StreamController<List<ConnectivityResult>>.broadcast();
    final gate = ConnectivityGate(
      stream: source.stream,
      // The load-bearing 7.x gotcha: "some connectivity" is never enough.
      check: () async => [ConnectivityResult.mobile, ConnectivityResult.vpn],
    );
    await gate.initialise();

    expect(gate.onWifi, isFalse);
  });

  test('stream emits deduped wifi transitions', () async {
    final source = StreamController<List<ConnectivityResult>>.broadcast();
    final gate = ConnectivityGate(
      stream: source.stream,
      check: () async => [ConnectivityResult.wifi],
    );
    await gate.initialise();

    final events = <bool>[];
    final sub = gate.wifiChanges.listen(events.add);

    source.add([ConnectivityResult.wifi, ConnectivityResult.vpn]); // still on
    source.add([ConnectivityResult.mobile]); // lost
    source.add([ConnectivityResult.mobile, ConnectivityResult.vpn]); // still off
    source.add([ConnectivityResult.none]); // still off
    source.add([ConnectivityResult.wifi]); // back
    await Future<void>.delayed(Duration.zero);

    expect(events, [false, true],
        reason: 'only genuine transitions, no repeats');
    expect(gate.onWifi, isTrue);
    await sub.cancel();
    await gate.dispose();
  });

  test('dispose cancels the subscription', () async {
    final source = StreamController<List<ConnectivityResult>>.broadcast();
    final gate = ConnectivityGate(
      stream: source.stream,
      check: () async => [ConnectivityResult.none],
    );
    await gate.initialise();

    await gate.dispose();

    expect(source.hasListener, isFalse);
  });
}
