import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// WiFi-or-nothing connectivity signal for the upload queue.
///
/// connectivity_plus 7.x emits a LIST of interfaces (a device can be on
/// WiFi + VPN at once). The owner's constraint is WiFi-only, so the single
/// question this answers is "does the list contain wifi" — a list with only
/// mobile/vpn/ethernet counts as NOT WiFi, never "good enough".
class ConnectivityGate {
  final Stream<List<ConnectivityResult>> _stream;
  final Future<List<ConnectivityResult>> Function() _check;

  final _changes = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _onWifi = false;

  ConnectivityGate({
    Stream<List<ConnectivityResult>>? stream,
    Future<List<ConnectivityResult>> Function()? check,
  })  : _stream = stream ?? Connectivity().onConnectivityChanged,
        _check = check ?? (() => Connectivity().checkConnectivity());

  static bool _hasWifi(List<ConnectivityResult> results) =>
      results.contains(ConnectivityResult.wifi);

  bool get onWifi => _onWifi;

  /// Deduped wifi-ness transitions: emits only when the answer changes.
  Stream<bool> get wifiChanges => _changes.stream;

  /// One-shot check to seed [onWifi], then subscribe for changes.
  Future<void> initialise() async {
    _onWifi = _hasWifi(await _check());
    _sub = _stream.listen((results) {
      final nowOnWifi = _hasWifi(results);
      if (nowOnWifi == _onWifi) return;
      _onWifi = nowOnWifi;
      _changes.add(nowOnWifi);
    });
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _changes.close();
  }
}
