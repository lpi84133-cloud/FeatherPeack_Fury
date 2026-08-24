import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_info.dart';
import 'core/theme/fp_theme.dart';
import 'crestway/crest_boot.dart';
import 'crestway/keep/boot_log.dart';
import 'crestway/pages/ascent_splash.dart';
import 'crestway/pages/ridge_portal.dart';
import 'crestway/wire/ridge_relay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(FpTheme.overlayStyle);

  final ready = await CrestBoot.ready();

  runApp(
    ProviderScope(
      child: FeatherpeakFuryApp(ready: ready),
    ),
  );
}

class FeatherpeakFuryApp extends StatefulWidget {
  const FeatherpeakFuryApp({super.key, required this.ready});

  final CrestReady ready;

  @override
  State<FeatherpeakFuryApp> createState() => _FeatherpeakFuryAppState();
}

class _FeatherpeakFuryAppState extends State<FeatherpeakFuryApp> {
  final _navKey = GlobalKey<NavigatorState>();
  StreamSubscription<String>? _pushUrlSub;

  @override
  void initState() {
    super.initState();
    // Push tap while the app is already alive (background / foreground):
    // reroute to the portal regardless of the current route.
    _pushUrlSub = RidgeRelay.instance.onUrl.listen((url) {
      final nav = _navKey.currentState;
      if (nav == null) return;
      crestLog(() => '[Crestway] in-session push $url');
      nav.push(
        MaterialPageRoute(
          builder: (_) => RidgePortal(
            url: url,
            userAgent: widget.ready.userAgent,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _pushUrlSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navKey,
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: FpTheme.build(),
      builder: (context, child) {
        final scaler = MediaQuery.textScalerOf(
          context,
        ).clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: child!,
        );
      },
      home: AscentSplash(
        coordinator: widget.ready.coordinator,
        userAgent: widget.ready.userAgent,
      ),
    );
  }
}
