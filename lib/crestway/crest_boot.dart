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
    // Firebase is best-effort: if it fails (no plist, wrong bundle), the
    // gate falls back to native — but push is dead until the next launch
    // with a correct configuration.
    try {
      await Firebase.initializeApp();
    } catch (error) {
      crestLog(() => '[Crestway] Firebase.init: $error');
    }

    final vault = await PerchVault.open();
    final agent = await DeviceAgent.assemble();
    final signals = await FlightSignals.boot();
    await RidgeRelay.instance.boot();

    // Subscribe to token refresh so a late token still hits the config
    // endpoint (`gray_flow_guide.md` §"Config Request Contract").
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
