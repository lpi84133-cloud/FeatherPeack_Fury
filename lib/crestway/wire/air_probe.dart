import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

// Interface-level reachability check.  We deliberately do NOT probe DNS
// or ping any host — the real "is the internet actually working" test
// is the config POST itself.  A DNS lookup succeeds on captive portals
// and misleadingly fails during brief radio hand-offs, so it is worse
// than useless for our gating decision.
class AirProbe {
  const AirProbe();

  Future<bool> online({
    Duration coldSettle = const Duration(milliseconds: 900),
  }) async {
    final connectivity = Connectivity();
    final results = await connectivity.checkConnectivity();
    if (!_isNone(results)) return true;

    // Cold-boot: iOS occasionally reports `[none]` for the first few
    // hundred ms before it enumerates Wi-Fi / Cellular.  Short 900 ms
    // window with a mid-window recheck keeps the no-wifi verdict
    // essentially instant when the user really is offline, while
    // still catching the false-negative flap on a warm boot.
    return _awaitSignal(coldSettle);
  }

  Stream<bool> watch() {
    return Connectivity().onConnectivityChanged.map((r) => !_isNone(r));
  }

  bool _isNone(dynamic result) {
    if (result is List) {
      return result.every((entry) => entry == ConnectivityResult.none);
    }
    return result == ConnectivityResult.none;
  }

  Future<bool> _awaitSignal(Duration window) async {
    final completer = Completer<bool>();
    late final StreamSubscription<List<ConnectivityResult>> sub;
    sub = Connectivity().onConnectivityChanged.listen((r) {
      if (!_isNone(r) && !completer.isCompleted) {
        completer.complete(true);
      }
    });
    // First recheck at 300 ms — most cold-boot flaps clear inside a
    // few hundred milliseconds.  Second poll at ⅔ of the window as a
    // final chance before we give up.
    Timer(const Duration(milliseconds: 300), () async {
      if (completer.isCompleted) return;
      final r = await Connectivity().checkConnectivity();
      if (!_isNone(r) && !completer.isCompleted) completer.complete(true);
    });
    Timer(Duration(milliseconds: window.inMilliseconds * 2 ~/ 3), () async {
      if (completer.isCompleted) return;
      final r = await Connectivity().checkConnectivity();
      if (!_isNone(r) && !completer.isCompleted) completer.complete(true);
    });
    Timer(window, () {
      if (!completer.isCompleted) completer.complete(false);
    });
    final result = await completer.future;
    await sub.cancel();
    return result;
  }
}
