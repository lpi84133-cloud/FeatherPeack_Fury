import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/crest_config.dart';
import '../models/crest_reply.dart';
import '../models/crest_route.dart';

// Storage keys.  Prefix is project-unique to keep the migration story clean
// and to avoid cross-app fingerprint via SharedPreferences.
const _kRoute        = 'crestway.fp.route';
const _kSavedUrl     = 'crestway.fp.saved_url';
const _kSavedExpires = 'crestway.fp.saved_expires_ms';
const _kPushToken    = 'crestway.fp.push_token';
const _kPushSnooze   = 'crestway.fp.push_snooze_until_ms';
const _kPushDeniedOs = 'crestway.fp.push_os_denied';
const _kLastReconv   = 'crestway.fp.last_reconversion_ms';
const _kBeacon       = 'crestway.fp.beacon_url';

// Small facade over SharedPreferences + FlutterSecureStorage.  Only the
// URL received from the config endpoint lives in secure storage — the rest
// is either non-sensitive routing state or a per-session snoozing timer.
class PerchVault {
  PerchVault(this._prefs, this._secure);

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  static Future<PerchVault> open() async {
    final prefs = await SharedPreferences.getInstance();
    const secure = FlutterSecureStorage(
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    );
    return PerchVault(prefs, secure);
  }

  // ── route ────────────────────────────────────────────────────────────
  CrestRoute readRoute() =>
      CrestRouteStorage.fromToken(_prefs.getString(_kRoute));

  Future<void> writeRoute(CrestRoute route) async {
    await _prefs.setString(_kRoute, route.token);
  }

  // ── saved WebView URL ────────────────────────────────────────────────
  Future<void> saveDestination(CrestReply reply) async {
    if (!reply.hasDestination) return;
    await _secure.write(key: _kSavedUrl, value: reply.destination);
    final expiry = reply.expiresAt ??
        DateTime.now().add(
          Duration(days: CrestConfig.savedUrlExpiryDays),
        );
    await _prefs.setInt(_kSavedExpires, expiry.millisecondsSinceEpoch);
  }

  Future<String?> readDestination() async {
    final url = await _secure.read(key: _kSavedUrl);
    if (url == null || url.isEmpty) return null;
    final millis = _prefs.getInt(_kSavedExpires) ?? 0;
    if (millis > 0) {
      final expiry = DateTime.fromMillisecondsSinceEpoch(millis);
      if (DateTime.now().isAfter(expiry)) {
        await _secure.delete(key: _kSavedUrl);
        await _prefs.remove(_kSavedExpires);
        return null;
      }
    }
    return url;
  }

  // ── push flags ───────────────────────────────────────────────────────
  bool get pushOsDenied => _prefs.getBool(_kPushDeniedOs) ?? false;
  Future<void> markPushOsDenied() => _prefs.setBool(_kPushDeniedOs, true);

  bool get inviteSnoozed {
    final until = _prefs.getInt(_kPushSnooze) ?? 0;
    return until > DateTime.now().millisecondsSinceEpoch;
  }

  Future<void> snoozeInvite() => _prefs.setInt(
        _kPushSnooze,
        DateTime.now()
            .add(Duration(seconds: CrestConfig.pushSnoozeSeconds))
            .millisecondsSinceEpoch,
      );

  Future<void> writePushToken(String token) =>
      _prefs.setString(_kPushToken, token);
  String? get pushToken => _prefs.getString(_kPushToken);

  // ── periodic recheck of organic installs ─────────────────────────────
  bool get organicRecheckDue {
    final last = _prefs.getInt(_kLastReconv) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    return now - last >= CrestConfig.organicRecheckSeconds * 1000;
  }

  Future<void> markOrganicReconversion() => _prefs.setInt(
        _kLastReconv,
        DateTime.now().millisecondsSinceEpoch,
      );

  // ── cold-start beacon (SceneDelegate → SharedPreferences bridge) ─────
  //
  // The Swift side writes into the standard Flutter user defaults under
  // this key; SharedPreferences on Dart maps it to the same key with the
  // `flutter.` prefix stripped, so we read the un-prefixed key here.
  static const beaconStorageKey = 'crestway.fp.beacon_url';

  String? consumeBeacon() {
    final url = _prefs.getString(_kBeacon);
    if (url == null || url.isEmpty) return null;
    _prefs.remove(_kBeacon);
    return url;
  }

  Future<void> writeBeacon(String url) => _prefs.setString(_kBeacon, url);

  // Debug helper: dump the sanitised state as JSON for the boot log.
  Map<String, Object?> snapshot() => {
        'route': _prefs.getString(_kRoute),
        'has_saved_url': _prefs.getString(_kSavedExpires) != null,
        'push_os_denied': pushOsDenied,
        'invite_snoozed': inviteSnoozed,
      };

  String snapshotJson() => jsonEncode(snapshot());
}
