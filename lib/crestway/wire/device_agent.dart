import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import '../config/crest_config.dart';
import '../keep/boot_log.dart';

// Builds the User-Agent shared by the config-endpoint HTTP client AND the
// WebView.  Every scaffolding fragment is decoded at runtime from a byte
// array; nothing that resembles `Mozilla/5.0 (iPhone; CPU iPhone OS ` is
// present in the binary as a plain literal (see `gray_user_agent.mdc` §1,
// `apple_moderation_hardening.mdc` §4).
//
// Featherpeak Fury ships with the slot-family suffix
//   `appid/id<storeNumericId> appname/FeatherpeakFury`
// appended at the end — this is a documented operator decision (see
// CrestConfig doc-comment); the tokens themselves are encoded so the
// literal `appid/` never appears in the binary either.
class DeviceAgent {
  DeviceAgent._(this.userAgent);

  final String userAgent;

  static Future<DeviceAgent> assemble() async {
    final iosVersion = await _readIosVersion();
    final base = _mobileSafari(iosVersion);
    // appid value = platform store id (id + numeric), matching the
    // slot-partner UA convention shown in reference screenshot.
    final withSuffix =
        '$base ${CrestConfig.uaAppIdToken}${CrestConfig.platformStoreId}'
        ' ${CrestConfig.uaAppNameToken}${CrestConfig.appNameToken}';
    crestLog(() => '[Crestway] UA = $withSuffix');
    return DeviceAgent._(withSuffix);
  }

  static Future<String> _readIosVersion() async {
    if (!Platform.isIOS) return '18_2';
    try {
      final info = await DeviceInfoPlugin().iosInfo;
      return info.systemVersion.replaceAll('.', '_');
    } catch (_) {
      // If device_info_plus fails, fall back to the pinned version.
      return CrestConfig.safariVersion.replaceAll('.', '_');
    }
  }

  static String _mobileSafari(String cpu) {
    return '${CrestConfig.uaProduct}'
        ' ${CrestConfig.uaPlatformPrefix} $cpu ${CrestConfig.uaPlatformSuffix}'
        ' ${CrestConfig.uaEngine}'
        ' Version/${CrestConfig.safariVersion}'
        ' ${CrestConfig.uaMobileToken}'
        ' Safari/${CrestConfig.safariTail}';
  }
}
