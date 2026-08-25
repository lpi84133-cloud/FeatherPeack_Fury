import 'package:firebase_core/firebase_core.dart';

import 'coordinator/crest_coordinator.dart';
import 'keep/boot_log.dart';
import 'wire/air_probe.dart';
import 'wire/crest_dispatch.dart';
import 'wire/device_agent.dart';
import 'wire/flight_signals.dart';
import 'wire/perch_vault.dart';
import 'wire/ridge_relay.dart';

// Boots all shell services in one place and returns a coordinator ready
// to `decide()`.  Called from `main` before `runApp` so the gate widget
// gets a fully-wired coordinator on first paint.
class CrestBoot {
  const CrestBoot._();

  static Future<CrestReady> ready() async {
    // Boot everything in parallel — none of these calls depend on each
    // other except RidgeRelay which needs Firebase.  Cutting them from
    // sequential to concurrent trims 1-2 s off the perceived splash
    // time on cold boot.
    final firebaseFuture = () async {
      try {
        await Firebase.initializeApp();
      } catch (error) {
        crestLog(() => '[Crestway] Firebase.init: $error');
      }
    }();
    final vaultFuture = PerchVault.open();
    final agentFuture = DeviceAgent.assemble();
    final signalsFuture = FlightSignals.boot();

    final vault = await vaultFuture;
    final agent = await agentFuture;
    await firebaseFuture;
    final signals = await signalsFuture;
    // RidgeRelay depends on Firebase being initialised.
    await RidgeRelay.instance.boot();

    RidgeRelay.instance.onTokenRefresh.listen((token) async {
      await vault.writePushToken(token);
      crestLog(() => '[Crestway] token refresh $token');
    });

    final coordinator = CrestCoordinator(
      vault: vault,
      signals: signals,
      probe: const AirProbe(),
      dispatch: CrestDispatch(userAgent: agent.userAgent),
      relay: RidgeRelay.instance,
    );

    return CrestReady(
      coordinator: coordinator,
      userAgent: agent.userAgent,
    );
  }
}

class CrestReady {
  const CrestReady({required this.coordinator, required this.userAgent});
  final CrestCoordinator coordinator;
  final String userAgent;
}
