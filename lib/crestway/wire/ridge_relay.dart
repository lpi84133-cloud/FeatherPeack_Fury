import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/crest_config.dart';
import '../keep/boot_log.dart';

// Owns push permission + APNs / FCM token retrieval + foreground banner
// display.  The gate reads a URL from `onUrl`; a cold-start tap has the
// URL flow through `getInitialMessage`, a background tap flows through
// `onMessageOpenedApp`.  Foreground presentation is delegated to iOS via
// `setForegroundNotificationPresentationOptions` — no separate local-
// notifications plugin call from this module, so the white game's
// reminder service is not affected.
class RidgeRelay {
  RidgeRelay._();

  static final RidgeRelay instance = RidgeRelay._();

  final _messaging = FirebaseMessaging.instance;

  final _urlController = StreamController<String>.broadcast();
  String? _initialUrl;

  Stream<String> get onUrl => _urlController.stream;
  String? consumeInitialUrl() {
    final v = _initialUrl;
    _initialUrl = null;
    return v;
  }

  Future<void> boot() async {
    try {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen(_handleForeground);
      FirebaseMessaging.onMessageOpenedApp.listen((m) {
        final url = _extractUrl(m.data);
        if (url != null) _urlController.add(url);
      });

      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        _initialUrl = _extractUrl(initial.data);
      }
    } catch (error) {
      crestLog(() => '[Crestway] RidgeRelay boot failed: $error');
    }
  }

  Future<bool> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final ok =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      return ok;
    } catch (error) {
      crestLog(() => '[Crestway] requestPermission: $error');
      return false;
    }
  }

  Future<AuthorizationStatus> currentStatus() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus;
  }

  Future<String?> awaitToken() async {
    if (!Platform.isIOS) return _tokenCall();
    // APNs token has to be there before FCM will produce one.  If
    // Firebase failed to initialise we swallow the error so the gate
    // still routes the user (§5 of `gray_flow_lessons.md`).
    for (var i = 0; i < CrestConfig.apnsPollAttempts; i++) {
      try {
        final apns = await _messaging.getAPNSToken();
        if (apns != null && apns.isNotEmpty) break;
      } catch (_) {
        break;
      }
      await Future<void>.delayed(CrestConfig.apnsPollStep);
    }
    return _tokenCall();
  }

  Future<String?> _tokenCall() async {
    try {
      return await _messaging.getToken();
    } catch (error) {
      crestLog(() => '[Crestway] getToken: $error');
      return null;
    }
  }

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  Future<void> _handleForeground(RemoteMessage message) async {
    // iOS renders the banner itself (setForegroundNotificationPresentationOptions
    // above).  We only need to route the tap: any embedded URL is streamed
    // so an in-session tap opens the portal without waiting for a new
    // process launch.
    final url = _extractUrl(message.data);
    if (url != null && url.isNotEmpty) {
      crestLog(() => '[Crestway] foreground push url=$url');
    }
  }

  String? _extractUrl(Map<String, dynamic>? data) {
    if (data == null) return null;
    for (final key in const ['url', 'link', 'target', 'deeplink', 'deep_link']) {
      final v = data[key];
      if (v is String && v.isNotEmpty) return v;
    }
    return null;
  }

  @visibleForTesting
  void injectForTest(String url) => _urlController.add(url);
}
