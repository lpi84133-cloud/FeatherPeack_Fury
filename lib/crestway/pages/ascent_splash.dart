import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/fp_colors.dart';
import '../../core/design/fp_images.dart';
import '../../core/design/fp_tokens.dart';
import '../../core/design/fp_typography.dart';
import '../../features/boot/boot_screen.dart';
import '../../shared/widgets/fp_progress_bar.dart';
import '../coordinator/crest_coordinator.dart';
import '../coordinator/crest_destination.dart';
import 'air_lost_page.dart';
import 'perch_invite.dart';
import 'ridge_portal.dart';

// The gate is intentionally visually indistinguishable from the game's
// existing boot screen: same background image, same wordmark, same
// gold-progress bar.  A pure-organic user sees the same splash they
// always would; the pipeline runs in the background and hands off to
// `BootScreen` before the bar reaches full.
class AscentSplash extends StatefulWidget {
  const AscentSplash({
    super.key,
    required this.coordinator,
    required this.userAgent,
  });

  final CrestCoordinator coordinator;
  final String userAgent;

  @override
  State<AscentSplash> createState() => _AscentSplashState();
}

class _AscentSplashState extends State<AscentSplash> {
  double _progress = 0;
  String _stageLabel = 'Warming up';
  bool _decided = false;

  static const _minVisible = Duration(milliseconds: 700);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      _tickBar();
      await _decide();
    });
  }

  Future<void> _tickBar() async {
    // A soft cosmetic bar so the splash never looks frozen.  Real routing
    // completes when `_decide` returns; this is UI only.
    const steps = [
      (0.20, 'Checking connection'),
      (0.45, 'Preparing your gear'),
      (0.72, 'Planning the trail'),
      (0.92, 'Almost ready'),
    ];
    for (final step in steps) {
      await Future<void>.delayed(const Duration(milliseconds: 320));
      if (!mounted || _decided) return;
      setState(() {
        _progress = step.$1;
        _stageLabel = step.$2;
      });
    }
  }

  Future<void> _decide() async {
    final started = DateTime.now();
    final destination = await widget.coordinator.decide();
    final elapsed = DateTime.now().difference(started);
    final remaining = _minVisible - elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
    if (!mounted) return;
    _decided = true;
    setState(() {
      _progress = 1.0;
      _stageLabel = 'Ready';
    });
    // Give the bar one frame to render at 100%.
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    _dispatch(destination);
  }

  void _dispatch(CrestDestination destination) {
    final ua = widget.userAgent;
    final coord = widget.coordinator;

    switch (destination) {
      case OpenNative():
        _swap(const BootScreen());
      case OpenPortal(url: final u, fromColdStartPush: final cold):
        _swap(RidgePortal(url: u, userAgent: ua, coldStartPush: cold));
      case InviteThenPortal(url: final u):
        _swap(PerchInvite(
          vault: coord.vault,
          nextPageBuilder: (_) => RidgePortal(url: u, userAgent: ua),
        ));
      case Unreachable():
        _swap(AirLostPage(
          retryPageBuilder: (_) => AscentSplash(
            coordinator: coord,
            userAgent: ua,
          ),
        ));
    }
  }

  void _swap(Widget page) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FpColors.forestDeep,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape = constraints.maxWidth > constraints.maxHeight;
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                isLandscape ? FpImages.bootLandscape : FpImages.bootPortrait,
                fit: BoxFit.cover,
                alignment: isLandscape
                    ? Alignment.center
                    : Alignment.topCenter,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00102008), Color(0xCC0E2206)],
                  ),
                ),
                child: SizedBox.expand(),
              ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal:
                        isLandscape ? FpSpace.xxl : FpSpace.lg,
                    vertical: FpSpace.lg,
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Text(
                                  _stageLabel,
                                  style: FpTypography.label.copyWith(
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: FpSpace.sm),
                              Text(
                                '${(_progress * 100).floor()}%',
                                style: FpTypography.metricSmall.copyWith(
                                  color: Colors.white,
                                  fontSize: isLandscape ? 18 : 20,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: isLandscape ? FpSpace.xs : FpSpace.sm,
                          ),
                          FpProgressBar(
                            value: _progress,
                            height: isLandscape ? 10 : 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
