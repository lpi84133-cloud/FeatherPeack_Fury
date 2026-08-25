import 'dart:async';
import 'dart:ui';

import '../config/crest_config.dart';
import '../keep/boot_log.dart';
import '../models/crest_reply.dart';
import '../models/crest_route.dart';
import '../wire/air_probe.dart';
import '../wire/crest_dispatch.dart';
import '../wire/flight_signals.dart';
import '../wire/launch_beacon.dart';
import '../wire/perch_vault.dart';
import '../wire/ridge_relay.dart';
import 'crest_destination.dart';

// Owns the whole routing pipeline for one process.  A concurrent call is
// de-duplicated via `_current`; the future is cleared on completion so a
// later Retry runs the pipeline fresh (`gray_flow_lessons.md` §3).
class CrestCoordinator {
  CrestCoordinator({
    required this.vault,
    required this.signals,
    required this.probe,
    required this.dispatch,
    required this.relay,
  });

  final PerchVault vault;
  final FlightSignals signals;
  final AirProbe probe;
  final CrestDispatch dispatch;
  final RidgeRelay relay;

  Future<CrestDestination>? _current;

  Future<CrestDestination> decide() =>
      _current ??= _decide().whenComplete(() => _current = null);

  Future<CrestDestination> _decide() async {
    if (!CrestConfig.portalCredentialsReady) {
      crestLog(() => '[Crestway] creds not ready → native');
      return const OpenNative();
    }

    final route = vault.readRoute();

    // Rule of the shell: once committed to a side, the user MUST stay on
    // that side for the rest of the install's life.  A gray user never
    // sees the white game and vice-versa (only two escape hatches: a
    // push tap that carries a fresh URL, and the first-launch decision).

    // Cold-start push tap always wins for gray-committed users so a push
    // notification can still deep-link into the WebView.  For a
    // native-committed user we deliberately IGNORE the push URL — the
    // rule "once native, always native" is stricter than any per-push
    // routing.
    if (route == CrestRoute.portal) {
      final beacon = await LaunchBeacon.consume();
      if (beacon != null) {
        crestLog(() => '[Crestway] portal + cold-start beacon $beacon');
        return OpenPortal(beacon, fromColdStartPush: true);
      }
      final fromFcm = relay.consumeInitialUrl();
      if (fromFcm != null && fromFcm.isNotEmpty) {
        crestLog(() => '[Crestway] portal + fcm initial $fromFcm');
        return OpenPortal(fromFcm, fromColdStartPush: true);
      }
      return _returningPortal();
    }

    // Native re-launches must NEVER touch the network — the game is
    // fully offline-capable and the route is sticky.
    if (route == CrestRoute.native) {
      // Drop any push URL that might have queued up; a native-committed
      // user cannot be flipped back to the WebView.
      await LaunchBeacon.consume();
      relay.consumeInitialUrl();
      return const OpenNative();
    }

    // Undecided — first launch.  Only this branch actually needs the
    // internet + AF + config dance; the outcome commits the route.
    final online = await probe.online();
    if (!online) {
      crestLog(() => '[Crestway] no interface → unreachable');
      return const Unreachable();
    }
    final beacon = await LaunchBeacon.consume();
    if (beacon != null) {
      crestLog(() => '[Crestway] first launch + cold-start beacon $beacon');
      await vault.writeRoute(CrestRoute.portal);
      return OpenPortal(beacon, fromColdStartPush: true);
    }
    final fromFcm = relay.consumeInitialUrl();
    if (fromFcm != null && fromFcm.isNotEmpty) {
      crestLog(() => '[Crestway] first launch + fcm initial $fromFcm');
      await vault.writeRoute(CrestRoute.portal);
      return OpenPortal(fromFcm, fromColdStartPush: true);
    }
    return _firstDecision();
  }

  // ── first launch ─────────────────────────────────────────────────────
  Future<CrestDestination> _firstDecision() async {
    // Online check already happened in `_decide` — do not repeat it.
    await signals.ensureTrackingPrompt();
    await signals.warmUp();
    await signals.awaitSignals(timeout: CrestConfig.awaitSignalsTimeout);

    final pushToken = await relay.awaitToken();
    if (pushToken != null && pushToken.isNotEmpty) {
      await vault.writePushToken(pushToken);
    }

    final locale = PlatformDispatcher.instance.locale.toString();
    final body = await signals.buildPayload(
      pushToken: pushToken,
      locale: locale,
    );
    final reply = await dispatch.post(body);
    return _commit(reply, firstLaunch: true);
  }

  Future<CrestDestination> _commit(
    CrestReply reply, {
    required bool firstLaunch,
  }) async {
    if (reply.hasDestination) {
      await vault.writeRoute(CrestRoute.portal);
      await vault.saveDestination(reply);
      return _wrapPortal(reply.destination!);
    }

    // We already passed the interface check in `_decide()` — the device
    // IS online.  Any "no destination" outcome (server said `ok:false`,
    // 4xx/5xx, malformed JSON, transport failure) means the user goes
    // to the native game.  Showing no-wifi here would create an infinite
    // retry loop while internet is fine — see the fantik-install bug in
    // `gray_flow_lessons.md` and the equivalent HenheavenDash
    // `_firstDecision` fallback (`DinerTarget`).  We only commit the
    // native route persistently when the server *explicitly* answered
    // (so a transport hiccup on the very first launch does not lock a
    // paid-install user into the game forever).
    if (firstLaunch && reply.serverAnswered) {
      await vault.writeRoute(CrestRoute.native);
    }
    return const OpenNative();
  }

  CrestDestination _wrapPortal(String url) {
    // Skip the push-permission promo if the user has already answered
    // (Accept or OS-level Deny both set pushDecisionMade), or if they
    // Skipped less than pushSnoozeSeconds ago.
    if (vault.pushDecisionMade) return OpenPortal(url);
    if (vault.pushOsDenied) return OpenPortal(url);
    if (vault.inviteSnoozed) return OpenPortal(url);
    return InviteThenPortal(url);
  }

  // ── returning portal user ────────────────────────────────────────────
  //
  // Sticky rule: a portal user must always land back in the WebView, even
  // if the network is dead or the config endpoint misbehaves.  Prefer the
  // cached URL and only try a fresh dispatch when there is nothing at
  // all in secure storage.  Never returns OpenNative.
  Future<CrestDestination> _returningPortal() async {
    final cached = await vault.readDestination();
    if (cached != null) {
      // Fast path: no network, no AF, no config POST.  A returning gray
      // user goes straight to the portal — this is what "user in gray
      // stays in gray on repeat launches" means at runtime.
      crestLog(() => '[Crestway] portal cached fast-path');
      // Kick a background refresh so the URL can be rotated silently,
      // but never gate the current launch on it.
      unawaited(_refreshCachedDestination());
      return _wrapPortal(cached);
    }

    // No cached URL (rare — usually only if the user hit no-wifi on
    // first launch after commit somehow).  We have to hit the network.
    final online = await probe.online();
    if (!online) return const Unreachable();

    await signals.warmUp();
    await signals.awaitSignals(timeout: const Duration(seconds: 3));
    final pushToken = vault.pushToken ?? await relay.awaitToken();
    final locale = PlatformDispatcher.instance.locale.toString();
    final body = await signals.buildPayload(
      pushToken: pushToken,
      locale: locale,
    );
    final reply = await dispatch.post(body);
    if (reply.hasDestination) {
      await vault.saveDestination(reply);
      return _wrapPortal(reply.destination!);
    }
    // Still portal-committed — no cached URL and the endpoint didn't
    // hand one back this launch.  Show no-wifi so the user can retry;
    // do NOT flip to native (rule: gray forever).
    return const Unreachable();
  }

  // Silent URL refresh for a returning portal user.  The current launch
  // has already been served from the cache — this only updates the
  // storage for the NEXT launch.  Any outcome that is not a fresh URL
  // is ignored: we never downgrade a committed portal user to native
  // from a background probe.
  Future<void> _refreshCachedDestination() async {
    try {
      if (!await probe.online()) return;
      await signals.warmUp();
      await signals.awaitSignals(timeout: const Duration(seconds: 4));
      final locale = PlatformDispatcher.instance.locale.toString();
      final pushToken = vault.pushToken;
      final body = await signals.buildPayload(
        pushToken: pushToken,
        locale: locale,
      );
      final reply = await dispatch.post(body);
      if (reply.hasDestination) {
        await vault.saveDestination(reply);
        crestLog(() => '[Crestway] portal URL refreshed silently');
      }
    } catch (error) {
      crestLog(() => '[Crestway] silent refresh failed: $error');
    }
  }
}
