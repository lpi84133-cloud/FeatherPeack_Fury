import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Offline / unreachable-endpoint screen.  Uses the delivered artwork in
// both orientations.  Retry re-runs the whole pipeline through this
// page's OWN Navigator (never a captured parent state — the previous
// gate route was `pushReplacement`d away, see
// `gray_flow_lessons.md` §3).
class AirLostPage extends StatefulWidget {
  const AirLostPage({super.key, required this.retryPageBuilder});

  final WidgetBuilder retryPageBuilder;

  @override
  State<AirLostPage> createState() => _AirLostPageState();
}

class _AirLostPageState extends State<AirLostPage> {
  StreamSubscription<List<ConnectivityResult>>? _netWatch;
  bool _restored = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Auto-restore: the moment the OS reports a live interface again,
    // slip the user back to the retry page (which normally rebuilds the
    // portal at the exact URL they were on).  A manual tap on the Retry
    // button still works and is the fallback when the stream misses.
    _netWatch = Connectivity().onConnectivityChanged.listen((results) {
      final anyUp =
          results.any((r) => r != ConnectivityResult.none);
      if (!anyUp || _restored || !mounted) return;
      // 2.5 s settle: connectivity_plus fires the moment the interface
      // is UP, but iOS's network stack (DNS, routing, TLS handshake to
      // the config endpoint) needs another 1-2 s before HTTPS works
      // reliably.  Retrying too early lands on a second no-wifi.
      Future<void>.delayed(const Duration(milliseconds: 2500), () {
        if (!mounted || _restored) return;
        _retry();
      });
    });
  }

  @override
  void dispose() {
    _netWatch?.cancel();
    super.dispose();
  }

  void _retry() {
    if (!mounted || _restored) return;
    _restored = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: widget.retryPageBuilder),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E2206),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final landscape = constraints.maxWidth > constraints.maxHeight;
          final art = landscape
              ? 'assets/crestway/nowifi_landscape.webp'
              : 'assets/crestway/nowifi_portrait.webp';
          final button = _RetryButton(
            onPressed: _retry,
            compact: landscape,
          );

          final content = Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                art,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xB3000000)],
                  ),
                ),
              ),
              Align(
                alignment: landscape
                    ? const Alignment(0, 0.88)
                    : const Alignment(0, 0.72),
                child: button,
              ),
            ],
          );

          // No SafeArea wrapper — the no-wifi screen sits edge-to-edge,
          // like the notify screen.  Only the WebView (RidgePortal) gets
          // a SafeArea around the actual site content.
          return content;
        },
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.onPressed, required this.compact});

  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = MediaQuery.of(context).size.width *
            (compact ? 0.35 : 0.70);
        return SizedBox(
          width: width,
          height: compact ? 52 : 60,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE7A924),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: onPressed,
            child: const Text(
              'Try again',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                height: 1.0,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}
