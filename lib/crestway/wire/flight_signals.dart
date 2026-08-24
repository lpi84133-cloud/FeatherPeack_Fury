import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../config/crest_config.dart';
import '../keep/boot_log.dart';

// Thin wrapper on top of AppsflyerSdk that produces the flat payload the
// config endpoint expects (device fields + verbatim conversion data).
//
// A first-launch answer without an address commits the route to the game
// forever, so nothing that can block or fail may run before both link
// checks pass and the ATT prompt has settled — see `gray_flow_lessons.md`
// §25 (attribution ordering) and §26 (ATT + memoisation).
class FlightSignals {
  FlightSignals._(this._sdk);

  final AppsflyerSdk _sdk;
  Map<String, dynamic>? _conversion;
  Map<String, dynamic>? _deepLink;
  Completer<void>? _conversionReady;
  Completer<void>? _deepLinkReady;

  Future<void>? _consentFuture;

  static Future<FlightSignals> boot() async {
    final sdk = AppsflyerSdk(
      AppsFlyerOptions(
        afDevKey: CrestConfig.appsFlyerDevKey,
        appId: CrestConfig.iosStoreNumericId,
        showDebug: kDebugMode,
        // 0 — we drive the ATT prompt ourselves and never rely on the SDK
        // to gate on it.  This avoids the "consent lost for a whole run"
        // trap described in gray_flow_lessons.md §26.
        timeToWaitForATTUserAuthorization: 0,
      ),
    );
    return FlightSignals._(sdk);
  }

  /// Presents the ATT prompt exactly once per install.  The prompt is only
  /// shown while the app is frontmost; if we're not resumed yet we wait
  /// for the lifecycle to settle and try again.
  Future<void> ensureTrackingPrompt() {
    return _consentFuture ??= _presentAtt();
  }

  Future<void> _presentAtt() async {
    if (!Platform.isIOS) return;
    try {
      await SchedulerBinding.instance.endOfFrame;
      await Future<void>.delayed(CrestConfig.attPromptDelay);
      final status =
          await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status != TrackingStatus.notDetermined) return;
      await AppTrackingTransparency.requestTrackingAuthorization();
    } catch (error) {
      crestLog(() => '[Crestway] ATT prompt failed: $error');
    }
  }

  /// Registers callbacks + kicks off the SDK.  Idempotent.
  Future<void> warmUp() async {
    _conversionReady ??= Completer<void>();
    _deepLinkReady ??= Completer<void>();

    _sdk.onInstallConversionData((raw) {
      _conversion = _asMap(raw);
      if (!(_conversionReady!.isCompleted)) _conversionReady!.complete();
    });
    _sdk.onDeepLinking((deepLink) {
      final dl = deepLink.deepLink;
      final flat = <String, dynamic>{};
      if (dl != null) {
        if (dl.deepLinkValue != null) flat['deep_link_value'] = dl.deepLinkValue;
        if (dl.matchType != null) flat['match_type'] = dl.matchType;
        if (dl.mediaSource != null) flat['media_source'] = dl.mediaSource;
        if (dl.campaign != null) flat['campaign'] = dl.campaign;
        if (dl.campaignId != null) flat['campaign_id'] = dl.campaignId;
        if (dl.afSub1 != null) flat['af_sub1'] = dl.afSub1;
        if (dl.afSub2 != null) flat['af_sub2'] = dl.afSub2;
        if (dl.afSub3 != null) flat['af_sub3'] = dl.afSub3;
        if (dl.afSub4 != null) flat['af_sub4'] = dl.afSub4;
        if (dl.afSub5 != null) flat['af_sub5'] = dl.afSub5;
      }
      _deepLink = flat;
      if (!(_deepLinkReady!.isCompleted)) _deepLinkReady!.complete();
    });

    try {
      await _sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: false,
        registerOnDeepLinkingCallback: true,
      );
    } catch (error) {
      crestLog(() => '[Crestway] AF init failed: $error');
      // Give the pipeline a way out — if init fails the completers must
      // still resolve so the config POST can proceed with the device
      // fields alone.
      if (!(_conversionReady!.isCompleted)) _conversionReady!.complete();
      if (!(_deepLinkReady!.isCompleted)) _deepLinkReady!.complete();
    }
  }

  /// Waits until the SDK has produced a verdict or the timeout expires.
  /// Returning early on timeout is intentional — a first-launch answer
  /// without attribution is still an answer.
  Future<void> awaitSignals({
    Duration timeout = const Duration(seconds: 7),
  }) async {
    if (_conversionReady == null) await warmUp();
    try {
      await Future.wait([
        _conversionReady!.future,
        _deepLinkReady!.future,
      ]).timeout(timeout);
    } on TimeoutException {
      crestLog(() => '[Crestway] AF signals timed out');
    }
  }

  bool get isOrganic {
    final status = (_conversion?['af_status'] ?? '').toString().toLowerCase();
    return status == 'organic';
  }

  bool get hasVerdict {
    final status = (_conversion?['af_status'] ?? '').toString();
    return status.isNotEmpty;
  }

  Future<String?> get appsFlyerUid async {
    try {
      return await _sdk.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  /// Assembles the flat JSON body posted to the config endpoint.
  Future<Map<String, dynamic>> buildPayload({
    String? pushToken,
    required String locale,
  }) async {
    final body = <String, dynamic>{};

    // Verbatim forward of AppsFlyer's conversion data.
    if (_conversion != null) {
      _conversion!.forEach((key, value) {
        if (value == null) return;
        body[key] = value;
      });
    }
    if (_deepLink != null) {
      _deepLink!.forEach((key, value) {
        if (value == null) return;
        body.putIfAbsent(key, () => value);
      });
    }

    // Device-side additions.
    body['af_id'] = await appsFlyerUid;
    body['bundle_id'] = CrestConfig.bundleId;
    body['os'] = 'iOS';
    body['store_id'] = CrestConfig.platformStoreId;
    body['locale'] = locale;

    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
      body['firebase_project_id'] = CrestConfig.firebaseProjectNumber;
    }

    // Drop nulls and empty strings so the endpoint receives a clean flat
    // body — omit-when-missing is the invariant on the token fields (see
    // gray_flow_lessons.md §12 / gray_flow_guide.md §"Config Request").
    body.removeWhere((_, value) {
      if (value == null) return true;
      if (value is String && value.isEmpty) return true;
      return false;
    });

    return body;
  }

  Map<String, dynamic>? _asMap(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }
}
