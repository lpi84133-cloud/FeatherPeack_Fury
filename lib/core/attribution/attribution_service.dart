import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../app_info.dart';

/// Measures whether this install arrived from a paid AppsFlyer OneLink campaign
/// (non-organic) or from direct App Store discovery (organic).
///
/// It is deliberately read-only from the app's point of view: it loads no URLs,
/// changes no navigation and never blocks start-up. Call [start] once from
/// [main] as fire-and-forget — the method never throws and runs entirely in the
/// background after the first frame.
class AttributionService {
  AttributionService._();

  /// AppsFlyer account dev key. This is a per-account credential taken from the
  /// AppsFlyer dashboard (App settings → Dev key). Replace the placeholder with
  /// the real key for this app before shipping — until then the SDK initialises
  /// but reports no valid attribution.
  static const _devKey = 'YOUR_APPSFLYER_DEV_KEY';

  /// Apple numeric App Store id, reused from the published app metadata.
  static const _appId = AppInfo.appStoreId;

  static AppsflyerSdk? _sdk;

  /// True once AppsFlyer has classified this install as organic, false when it
  /// is non-organic, null while the classification is still pending.
  static bool? _isOrganic;
  static bool? get isOrganic => _isOrganic;

  /// Initialises the attribution pipeline.
  ///
  /// Order of operations:
  ///   1. Wait for the first rendered frame so the app is visible before any
  ///      system dialog appears.
  ///   2. Request ATT authorisation on iOS 14+ (skipped if already answered).
  ///   3. Initialise the AppsFlyer SDK and register the conversion callback.
  static Future<void> start() async {
    try {
      await WidgetsBinding.instance.endOfFrame;
      await _requestTrackingIfNeeded();

      final sdk = AppsflyerSdk(
        AppsFlyerOptions(
          afDevKey: _devKey,
          appId: _appId,
          showDebug: kDebugMode,
          timeToWaitForATTUserAuthorization: 5,
        ),
      );
      _sdk = sdk;

      sdk.onInstallConversionData(_onConversionData);

      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: false,
        registerOnDeepLinkingCallback: false,
      );
    } catch (error) {
      assert(() {
        debugPrint('[Attribution] init failed: $error');
        return true;
      }());
    }
  }

  static Future<void> _requestTrackingIfNeeded() async {
    if (!Platform.isIOS) return;
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status != TrackingStatus.notDetermined) return;
    // Brief pause so the UI is fully drawn before the system sheet appears.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    await AppTrackingTransparency.requestTrackingAuthorization();
  }

  /// AppsFlyer delivers the install classification here. `af_status` is either
  /// "Organic" or "Non-organic"; the media source names the campaign when the
  /// install came through a OneLink.
  static void _onConversionData(dynamic raw) {
    final map = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final inner = map['payload'];
    final data = inner is Map ? Map<String, dynamic>.from(inner) : map;

    final afStatus = (data['af_status'] ?? '').toString();
    if (afStatus.isNotEmpty) {
      _isOrganic = afStatus.toLowerCase() == 'organic';
    }

    assert(() {
      final mediaSource = data['media_source'] ?? '—';
      debugPrint(
        '[Attribution] af_status=$afStatus  media_source=$mediaSource',
      );
      return true;
    }());
  }

  /// The AppsFlyer UID for this device, or null if the SDK has not initialised
  /// yet or the lookup fails.
  static Future<String?> appsFlyerUID() async {
    try {
      return await _sdk?.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }
}
