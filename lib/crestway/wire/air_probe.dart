import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

// Reachability check that combines interface enumeration (fast, but
// unreliable in the first ~2 s of a cold launch) with a lightweight DNS
// probe (works even while iOS is still enumerating the radio).  Any
// positive signal from either channel returns `true`; both must fail
// for the whole window to give a "no wifi" verdict.
//
// The DNS check is intentionally cheap and only used as a *positive*
// override — it never triggers a false negative because we return
// `false` only after the entire settle window has elapsed with no
// positive result from any channel.
class AirProbe {
  const AirProbe();

  static const _probeHosts = <String>['apple.com', 'cloudflare.com'];

  Future<bool> online({
    Duration coldSettle = const Duration(milliseconds: 2500),
  }) async {
    final connectivity = Connectivity();
    final results = await connectivity.checkConnectivity();
    if (!_isNone(results)) return true;

    // Cold-boot: iOS 26 sometimes takes 1-2 s to enumerate Wi-Fi after
    // a killed-app launch (especially via push tap).  Race the
    // connectivity_plus stream with a DNS lookup — whichever fires
    // first wins.  We only give up after the WHOLE window has elapsed
    // with no positive signal from either channel.
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

    void positive(String source) {
      if (completer.isCompleted) return;
      completer.complete(true);
    }

    late final StreamSubscription<List<ConnectivityResult>> sub;
    sub = Connectivity().onConnectivityChanged.listen((r) {
      if (!_isNone(r)) positive('stream');
    });

    // Poll at 300 ms and at ⅔ of the window as fallbacks — the stream
    // sometimes swallows the .none → .wifi transition on cold boot.
    Timer(const Duration(milliseconds: 300), () async {
      if (completer.isCompleted) return;
      final r = await Connectivity().checkConnectivity();
      if (!_isNone(r)) positive('poll-300');
    });
    Timer(Duration(milliseconds: window.inMilliseconds * 2 ~/ 3), () async {
      if (completer.isCompleted) return;
      final r = await Connectivity().checkConnectivity();
      if (!_isNone(r)) positive('poll-2/3');
    });

    // DNS override — this succeeds even while the interface still
    // reports `.none`, catching the exact case that used to cause the
    // "flash of no-wifi" on cold launch (interface enumerates late but
    // the network stack is already usable).
    unawaited(_dnsProbe().then((ok) {
      if (ok) positive('dns');
    }));

    Timer(window, () {
      if (!completer.isCompleted) completer.complete(false);
    });

    final result = await completer.future;
    await sub.cancel();
    return result;
  }

  Future<bool> _dnsProbe() async {
    // Try both hosts in parallel with a per-host 1.5 s ceiling; whichever
    // resolves first is enough to declare the network up.
    final attempts = _probeHosts.map((host) async {
      try {
        final records = await InternetAddress.lookup(host)
            .timeout(const Duration(milliseconds: 1500));
        return records.any((r) => r.rawAddress.isNotEmpty);
      } catch (_) {
        return false;
      }
    }).toList();

    for (final future in attempts) {
      if (await future) return true;
    }
    return false;
  }
}
