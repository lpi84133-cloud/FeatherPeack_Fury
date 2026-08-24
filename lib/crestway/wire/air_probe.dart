import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

// Two-step reachability check.  A `ConnectivityResult.none` verdict is
// treated as authoritative offline immediately — no probe is fired,
// because a DNS lookup with no interface hangs for seconds while the
// WebView paints its own error page (`gray_flow_lessons.md` §2).
class AirProbe {
  const AirProbe();

  Future<bool> online({Duration timeout = const Duration(seconds: 3)}) async {
    final connectivity = Connectivity();
    final results = await connectivity.checkConnectivity();
    if (_isNone(results)) return false;
    return _dnsProbe(timeout);
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

  Future<bool> _dnsProbe(Duration timeout) async {
    // Multiple hosts so a single blocked target (captive-portal hijack,
    // DoH filter, corporate proxy) never fabricates an offline verdict.
    // Set rotated per project (`gray_part_mixing_review.mdc` §1) — no
    // overlap with sibling shells using `apple.com` / `cloudflare.com`.
    const hosts = <String>[
      'www.icloud.com',
      'one.one.one.one',
      'www.bing.com',
    ];
    for (final host in hosts) {
      try {
        final lookup =
            await InternetAddress.lookup(host).timeout(timeout);
        if (lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty) {
          return true;
        }
      } on Object {
        // Try the next host before declaring offline.
      }
    }
    return false;
  }
}
