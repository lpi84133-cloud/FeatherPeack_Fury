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

    // A cold-start push URL always wins.  It is one-shot: `consume()` and
    // `consumeInitialUrl()` clear their source so a later re-launch takes
    // the ordinary config path.
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

    final route = vault.readRoute();
    switch (route) {
      case CrestRoute.portal:
        return _returningPortal();
      case CrestRoute.native:
        return _returningNative();
      case CrestRoute.undecided:
        return _firstDecision();
    }
  }

  // ── first launch ─────────────────────────────────────────────────────
  Future<CrestDestination> _firstDecision() async {
    final online = await probe.online();
    if (!online) {
      crestLog(() => '[Crestway] first launch offline');
      return const Unreachable();
    }

    // ATT prompt must run before we start awaiting signals; if the SDK
    // starts first the prompt gets dropped on backgrounded starts
    // (`gray_flow_lessons.md` §26).
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

    // No URL — but we DID reach the endpoint (message present).  Only
    // commit `native` on a real answer; a transport failure keeps the
    // route as undecided so the next launch tries again
    // (`gray_flow_lessons.md` invariant 3).
    if (reply.rawMessage != null && reply.rawMessage!.isNotEmpty) {
      if (firstLaunch) await vault.writeRoute(CrestRoute.native);
      return const OpenNative();
    }

    return firstLaunch ? const Unreachable() : const OpenNative();
  }

  CrestDestination _wrapPortal(String url) {
    // Skip the push-permission promo if the user has already answered at
    // the system level, or if they snoozed less than pushSnoozeSeconds ago.
    if (vault.pushOsDenied) return OpenPortal(url);
    if (vault.inviteSnoozed) return OpenPortal(url);
    return InviteThenPortal(url);
  }

  // ── returning portal user ────────────────────────────────────────────
  Future<CrestDestination> _returningPortal() async {
    final online = await probe.online();
    if (!online) return const Unreachable();

    // Try a fresh POST first — the endpoint may have rotated the partner
    // host.  If it fails, fall back to the saved URL only if still valid.
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

    final saved = await vault.readDestination();
    if (saved != null) return _wrapPortal(saved);

    // The endpoint told us to stop showing the portal — respect that,
    // flip to native.
    if (reply.rawMessage != null && reply.rawMessage!.isNotEmpty) {
      await vault.writeRoute(CrestRoute.native);
      return const OpenNative();
    }
    return const Unreachable();
  }

  // ── returning native user ────────────────────────────────────────────
  Future<CrestDestination> _returningNative() async {
    if (!vault.organicRecheckDue) return const OpenNative();

    final online = await probe.online();
    if (!online) return const OpenNative(); // do not park in offline

    unawaited(signals.warmUp());
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
      return _wrapPortal(reply.destination!);
    }
    return const OpenNative();
  }
}
