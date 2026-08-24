import 'dart:async';
import 'dart:convert';
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

    _sdk.onInstallConversionData(_takeInstall);
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

  /// Waits until the SDK has produced a verdict or the per-completer
  /// timeouts expire.  Deep-link and conversion get separate ceilings so
  /// a missing deep-link (the common case — no deferred link) never blocks
  /// the whole flow for the full conversion window.
  Future<void> awaitSignals({
    Duration timeout = const Duration(seconds: 17),
  }) async {
    if (_conversionReady == null) await warmUp();
    // Deep-link callback often never fires (no deferred deep link on this
    // install).  Give it a short window and move on regardless.
    final deepLinkCeiling = Duration(
      seconds: (timeout.inSeconds ~/ 3).clamp(3, 6),
    );
    await Future.wait<void>(<Future<void>>[
      _conversionReady!.future.timeout(timeout, onTimeout: () {
        crestLog(() => '[Crestway] AF conversion timed out');
      }),
      _deepLinkReady!.future.timeout(deepLinkCeiling, onTimeout: () {}),
    ]);
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

  // ── Install-conversion callback + organic lookup fallback ─────────────
  //
  // AppsFlyer's SDK sometimes reports a paid install as `af_status: Organic`
  // on the very first callback of a fresh install (a race between the
  // click-server and the SDK's own attribution window).  Forwarding that
  // verdict verbatim would push a legit non-organic user into the native
  // game.  Mirror the working sibling project (`Joker-Lantern/torch_trail`):
  // when we see Organic, wait a beat and re-read via the GCD lookup API
  // before committing.
  Future<void> _takeInstall(dynamic raw) async {
    try {
      final received = _unwrap(raw);
      final status = received['status']?.toString().toLowerCase();
      final broken = status == 'failure' ||
          (received['af_status'] == null && received.containsKey('status'));

      crestLog(() =>
          '[Crestway] AF install status=$status af_status=${received['af_status']} '
          'keys=${received.keys.toList()}');

      if (broken) {
        _conversion = <String, dynamic>{};
      } else if ((received['af_status']?.toString().toLowerCase()) ==
          'organic') {
        await Future<void>.delayed(
          Duration(seconds: CrestConfig.organicRecheckSeconds),
        );
        _conversion = await _gcdLookup() ?? received;
      } else {
        _conversion = received;
      }
    } catch (error) {
      crestLog(() => '[Crestway] AF install parse failed: $error');
      _conversion = <String, dynamic>{};
    } finally {
      if (!(_conversionReady?.isCompleted ?? true)) {
        _conversionReady!.complete();
      }
    }
  }

  // Unwrap the nested container the SDK sometimes puts the actual
  // conversion data into.  Both `payload` (iOS bridge) and `data` (Android
  // bridge / newer iOS versions) are seen in the wild — try each.
  Map<String, dynamic> _unwrap(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final map = Map<String, dynamic>.from(raw);
    for (final key in const <String>['payload', 'data']) {
      final nested = map[key];
      if (nested is Map) return Map<String, dynamic>.from(nested);
    }
    return map;
  }

  // Server-side attribution lookup — the GCD (Get Conversion Data) API.
  // Keyed by the numeric store id and the AppsFlyer UID; auth is the same
  // dev key the SDK uses.  Returns null on any failure so the caller falls
  // back to the (possibly-wrong) SDK verdict rather than blanking the body.
  Future<Map<String, dynamic>?> _gcdLookup() async {
    final uid = await appsFlyerUid;
    if (uid == null || uid.isEmpty) return null;
    final base = CrestConfig.gcdBase;
    final devKey = CrestConfig.appsFlyerDevKey;
    if (base.isEmpty || devKey.isEmpty) return null;
    final client = HttpClient()..connectionTimeout = CrestConfig.gcdLookupTimeout;
    try {
      final uri = Uri.parse(
        '$base/install_data/v5.0/${CrestConfig.iosStoreNumericId}'
        '?device_id=$uid',
      );
      final req = await client.getUrl(uri).timeout(CrestConfig.gcdLookupTimeout);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $devKey');
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response =
          await req.close().timeout(CrestConfig.gcdLookupTimeout);
      if (response.statusCode != 200) {
        crestLog(() => '[Crestway] GCD lookup ${response.statusCode}');
        return null;
      }
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        crestLog(() => '[Crestway] GCD lookup OK af_status=${decoded['af_status']}');
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    } catch (error) {
      crestLog(() => '[Crestway] GCD lookup failed: $error');
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
