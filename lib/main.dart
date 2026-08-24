import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_info.dart';
import 'core/attribution/attribution_service.dart';
import 'core/theme/fp_theme.dart';
import 'features/boot/boot_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(FpTheme.overlayStyle);
  runApp(const ProviderScope(child: FeatherpeakFuryApp()));
  // Fire-and-forget: attribution runs after the first frame and never blocks
  // the launch, so a slow or unreachable network cannot delay the UI.
  unawaited(AttributionService.start());
}

class FeatherpeakFuryApp extends StatelessWidget {
  const FeatherpeakFuryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: FpTheme.build(),
      // Text scaling is honoured but capped, so dense metric rows stay readable
      // at the extremes of the accessibility range.
      builder: (context, child) {
        final scaler = MediaQuery.textScalerOf(
          context,
        ).clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: child!,
        );
      },
      home: const BootScreen(),
    );
  }
}
