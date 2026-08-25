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

    // Native re-launches must NEVER touch the network — the game is
    // fully offline-capable.  A pending organic-→-portal recheck runs
    // fire-and-forget so the next launch picks up any new route.
    if (route == CrestRoute.native) {
      if (vault.organicRecheckDue) {
        unawaited(_backgroundRecheck());
      }
      return const OpenNative();
    }

    // Portal + undecided both require an internet-backed decision.
    // Do the interface check first — before any beacon / pipeline —
    // so a truly offline device gets the no-wifi screen instantly.
    final online = await probe.online();
    if (!online) {
      crestLog(() => '[Crestway] no interface → unreachable');
      return const Unreachable();
    }

    // A cold-start push URL wins ONLY when we actually have connectivity;
    // opening a WebView while offline just shows an ugly WK error page.
    final beacon = await LaunchBeacon.consume();
    if (beacon != null) {
      crestLog(() => '[Crestway] cold-start beacon $beacon');
      return OpenPortal(beacon, fromColdStartPush: true);
    }
    final fromFcm = relay.consumeInitialUrl();
    if (fromFcm != null && fromFcm.isNotEmpty) {
      crestLog(() => '[Crestway] fcm initial $fromFcm');
      return OpenPortal(fromFcm, fromColdStartPush: true);
    }

    switch (route) {
      case CrestRoute.portal:
        return _returningPortal();
      case CrestRoute.undecided:
        return _firstDecision();
      case CrestRoute.native:
        // Unreachable: handled above.
        return const OpenNative();
    }
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

    // Server responded (2xx JSON) but did not grant a URL — the endpoint
    // is intentionally sending the user to the game.  Commit the native
    // route on first launch so the next open goes straight to the game
    // (`gray_flow_lessons.md` invariant 3).
    if (reply.serverAnswered) {
      if (firstLaunch) await vault.writeRoute(CrestRoute.native);
      return const OpenNative();
    }

    // Transport failure — we could NOT reach the config endpoint and we
    // have no cached decision.  The routing decision requires the
    // config: no config, no decision.  Show no-wifi; a later retry
    // (or the connectivity auto-resume) will run the pipeline again.
    return const Unreachable();
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
  Future<CrestDestination> _returningPortal() async {
    // Online check already happened in `_decide`.
    unawaited(signals.warmUp());
    unawaited(signals.awaitSignals(timeout: const Duration(seconds: 3)));

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

    // Endpoint explicitly refused to grant a URL — respect the server
    // decision and flip the route to native.
    if (reply.serverAnswered) {
      await vault.writeRoute(CrestRoute.native);
      return const OpenNative();
    }

    // Endpoint unreachable — try the last cached destination if still
    // valid; otherwise no-wifi (we can't decide without the config).
    final saved = await vault.readDestination();
    if (saved != null) return _wrapPortal(saved);
    return const Unreachable();
  }

  // ── background recheck for native users ──────────────────────────────
  Future<void> _backgroundRecheck() async {
    try {
      final online = await probe.online();
      if (!online) return;
      await signals.warmUp();
      await signals.awaitSignals(timeout: const Duration(seconds: 4));
      await vault.markOrganicReconversion();

      final locale = PlatformDispatcher.instance.locale.toString();
      final pushToken = vault.pushToken;
      final body = await signals.buildPayload(
        pushToken: pushToken,
        locale: locale,
      );
      final reply = await dispatch.post(body);
      if (reply.hasDestination) {
        await vault.writeRoute(CrestRoute.portal);
        await vault.saveDestination(reply);
        crestLog(() => '[Crestway] background recheck → flipped to portal');
      }
    } on Object catch (error) {
      crestLog(() => '[Crestway] background recheck failed: $error');
    }
  }
}
