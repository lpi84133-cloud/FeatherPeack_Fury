import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../wire/perch_vault.dart';
import '../wire/ridge_relay.dart';

// Push-permission promo shown BEFORE the WebView on the very first entry
// to the portal path.  If the user denies system-level, the flag is set
// and the promo never shows again.  If they skip, we snooze it for
// `pushSnoozeSeconds` (see CrestConfig).
//
// The next page is passed in as a builder so PerchInvite navigates from
// its OWN context — the callback cannot rely on the previous route's
// state being alive (it was `pushReplacement`d away).
class PerchInvite extends StatefulWidget {
  const PerchInvite({
    super.key,
    required this.vault,
    required this.nextPageBuilder,
  });

  final PerchVault vault;
  final WidgetBuilder nextPageBuilder;

  @override
  State<PerchInvite> createState() => _PerchInviteState();
}

class _PerchInviteState extends State<PerchInvite> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // BootScreen locks portrait right before hand-off; re-enable landscape
    // for this screen (`gray_flow_lessons.md` §10).
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // No SafeArea wrapper — the notify screen has to sit under the
      // status bar and the home-indicator area (edge-to-edge artwork).
      // The WebView keeps its own SafeArea when the site loads.
      body: LayoutBuilder(
        builder: (context, constraints) {
          final landscape = constraints.maxWidth > constraints.maxHeight;
          final art = landscape
              ? 'assets/crestway/notify_landscape.webp'
              : 'assets/crestway/notify_portrait.webp';

          return Stack(
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
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xB3000000)],
                  ),
                ),
              ),
              // Buttons pinned near the bottom edge so they never sit on
              // top of the artwork's caption.  In landscape they go
              // side-by-side (Accept | Skip), in portrait they stack.
              Positioned(
                left: 0,
                right: 0,
                bottom: landscape ? 18 : 42,
                child: _Buttons(
                  enabled: !_busy,
                  onAccept: _accept,
                  onSkip: _skip,
                  landscape: landscape,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    final granted = await RidgeRelay.instance.requestPermission();
    if (!granted) await widget.vault.markPushOsDenied();
    _goNext();
  }

  Future<void> _skip() async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.vault.snoozeInvite();
    _goNext();
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: widget.nextPageBuilder),
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons({
    required this.enabled,
    required this.onAccept,
    required this.onSkip,
    required this.landscape,
  });

  final bool enabled;
  final VoidCallback onAccept;
  final VoidCallback onSkip;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    if (landscape) {
      // Row of two identical pills, centred horizontally.  Sizing is
      // driven by the parent Positioned so the notch does not shift the
      // visual centre.
      final width = MediaQuery.of(context).size.width;
      final pillWidth = (width * 0.34).clamp(180.0, 320.0);
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Pill(
            width: pillWidth,
            label: 'Accept',
            color: const Color(0xFFE7A924),
            textColor: Colors.white,
            onPressed: enabled ? onAccept : null,
            compact: true,
          ),
          const SizedBox(width: 14),
          _Pill(
            width: pillWidth,
            label: 'Skip',
            color: const Color(0xFF4E3B12),
            textColor: Colors.white,
            onPressed: enabled ? onSkip : null,
            compact: true,
          ),
        ],
      );
    }

    // Portrait — keep the stacked layout the artwork was designed for.
    final width = MediaQuery.of(context).size.width * 0.72;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Pill(
          width: width,
          label: 'Allow notifications',
          color: const Color(0xFFE7A924),
          textColor: Colors.white,
          onPressed: enabled ? onAccept : null,
          compact: false,
        ),
        const SizedBox(height: 14),
        _Pill(
          width: width,
          label: 'Not now',
          color: const Color(0xFF4E3B12),
          textColor: Colors.white,
          onPressed: enabled ? onSkip : null,
          compact: false,
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.width,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onPressed,
    required this.compact,
  });

  final double width;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: compact ? 50 : 58,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 16 : 18,
            fontWeight: FontWeight.w600,
            height: 1.0,
            letterSpacing: 0.2,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
