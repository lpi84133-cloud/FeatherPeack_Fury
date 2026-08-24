import 'package:shared_preferences/shared_preferences.dart';

// Bridge for the cold-start push URL captured by SceneDelegate.swift.
//
// SceneDelegate writes into the standard iOS user defaults under the key
// `flutter.crestway.fp.beacon_url`.  Flutter's SharedPreferences maps that
// to the un-prefixed key `crestway.fp.beacon_url` here.  `consume()` is
// destructive — the URL is one-shot; a re-launch after the WebView opens
// must fall back to the normal config path.
class LaunchBeacon {
  const LaunchBeacon._();

  static const String bridgeKey = 'crestway.fp.beacon_url';

  static Future<String?> consume() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(bridgeKey);
    if (url == null || url.isEmpty) return null;
    await prefs.remove(bridgeKey);
    return url;
  }
}
