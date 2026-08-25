import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/design/fp_colors.dart';
import '../../core/design/fp_images.dart';
import '../../core/design/fp_tokens.dart';
import '../../core/design/fp_typography.dart';
import '../../features/boot/boot_screen.dart';
import '../../shared/widgets/fp_progress_bar.dart';
import '../coordinator/crest_coordinator.dart';
import '../coordinator/crest_destination.dart';
import '../crest_boot.dart';
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
    this.readyFuture,
    this.coordinator,
    this.userAgent,
    this.initialProgress = 0.0,
  }) : assert(
          readyFuture != null || (coordinator != null && userAgent != null),
          'Provide either readyFuture (cold boot) or coordinator+userAgent (retry).',
        );

  // Path A — first render from main(): we get a future that resolves
  // to the fully-booted coordinator.  The splash renders instantly and
  // races the boot in the background; the connectivity check runs
  // even before boot completes so an offline user sees no-wifi ASAP.
  final Future<CrestReady>? readyFuture;

  // Path B — retry from AirLostPage: the coordinator is already ready.
  final CrestCoordinator? coordinator;
  final String? userAgent;

  // Where the progress bar picks up from when this splash is remounted
  // as a retry after the no-wifi screen.  Set to the ceiling (0.35) so
  // the bar continues the story the user last saw, instead of resetting
  // to 0 and re-running the 2-second ramp.
  final double initialProgress;

  @override
  State<AscentSplash> createState() => _AscentSplashState();
}

class _AscentSplashState extends State<AscentSplash>
    with SingleTickerProviderStateMixin {
  double _progress = 0;
  String _stageLabel = 'Warming up';
  bool _decided = false;
  Ticker? _ticker;
  Duration? _tickerStart;
  CrestCoordinator? _resolvedCoordinator;
  String? _resolvedUserAgent;

  // Linear 0 → 0.35 over 2 s.  The 35 % ceiling is a hard product
  // requirement: while a no-wifi outcome is still possible (i.e. the
  // config POST has not resolved yet), the bar must NEVER exceed 35 %.
  // Only the final 0.35 → 1.00 finish (kicked in `_decide` after a
  // non-Unreachable destination is known) crosses that line, right
  // before the destination widget mounts.
  static const _rampSpan = Duration(seconds: 2);
  static const _rampCeiling = 0.35;

  // Stage labels tied to progress thresholds — captions change calmly
  // as the bar fills without ever getting ahead of the fill itself.
  static const _stageLabels = <(double, String)>[
    (0.00, 'Warming up'),
    (0.10, 'Checking connection'),
    (0.20, 'Preparing your gear'),
    (0.28, 'Planning the trail'),
    (0.33, 'Almost ready'),
  ];

  @override
  void initState() {
    super.initState();
    _progress = widget.initialProgress.clamp(0.0, _rampCeiling);
    if (_progress > 0) {
      // Retry from no-wifi: pick up the story where the user saw it end.
      _stageLabel = 'Almost ready';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      _startTicker();
      // No parallel "early offline guard" any more — a false negative
      // there caused the flash-of-no-wifi bug (interface briefly reports
      // .none on cold boot → guard dispatches AirLostPage → auto-retry
      // bounces user back).  The coordinator's own probe (with a longer
      // settle window) is the single source of truth for connectivity.
      await _decide();
    });
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _startTicker() {
    // If we resumed at the ceiling (retry from no-wifi), just hold the
    // bar there — the ramp is meaningless from a starting point that is
    // already at the ceiling.
    if (_progress >= _rampCeiling - 0.001) {
      return;
    }
    _ticker = createTicker((elapsed) {
      _tickerStart ??= elapsed;
      if (_decided || !mounted) return;
      final delta = elapsed - _tickerStart!;
      final t = (delta.inMilliseconds / _rampSpan.inMilliseconds)
          .clamp(0.0, 1.0);
      // Bar never moves backwards — if the widget was mounted with a
      // non-zero initial progress, the linear ramp is offset so its
      // starting point matches the incoming value.
      final ramped = t * _rampCeiling;
      final target = ramped < _progress ? _progress : ramped;
      String label = _stageLabels.first.$2;
      for (final entry in _stageLabels) {
        if (target >= entry.$1) label = entry.$2;
      }
      if ((target - _progress).abs() < 0.001 && label == _stageLabel) return;
      setState(() {
        _progress = target;
        _stageLabel = label;
      });
    })..start();
  }

  Future<void> _decide() async {
    // Path A (first mount): wait for boot to finish before running the
    // pipeline.  Path B (retry): coordinator already provided directly.
    CrestCoordinator? coordinator = widget.coordinator;
    String? userAgent = widget.userAgent;
    if (coordinator == null || userAgent == null) {
      final ready = await widget.readyFuture!;
      if (_decided || !mounted) return;
      coordinator = ready.coordinator;
      userAgent = ready.userAgent;
    }

    final destination = await coordinator.decide();
    if (!mounted || _decided) return;
    // Remember the resolved values so `_dispatch` can use them.
    _resolvedCoordinator = coordinator;
    _resolvedUserAgent = userAgent;

    // Offline / no-config → dispatch to no-wifi immediately.  We do
    // NOT wait for the bar to reach the ceiling: the connectivity
    // check has to feel instant.  The retry from the no-wifi screen
    // still resumes at the 35 % ceiling, so the continuity story is
    // preserved without stalling here.
    if (destination is Unreachable) {
      _decided = true;
      _ticker?.stop();
      _dispatch(destination);
      return;
    }

    // Real decision — animate the remaining current → 1.00 tail smoothly,
    // hold on 100 % for a moment so the user sees it, THEN mount the
    // destination widget.  Never before 100 %.
    await _finishBar();
    if (!mounted) return;
    // Hold on 100 % — the user must see the finish before the next
    // widget appears.
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    _dispatch(destination);
  }

  Future<void> _finishBar() async {
    _decided = true;
    _ticker?.stop();
    // 900 ms so the ~65 % jump from the ceiling to the finish is a
    // visible arc, not a snap.
    const finishSpan = Duration(milliseconds: 900);
    final startProgress = _progress;
    final start = DateTime.now();
    while (mounted) {
      final elapsed = DateTime.now().difference(start);
      final t = (elapsed.inMilliseconds / finishSpan.inMilliseconds)
          .clamp(0.0, 1.0);
      final target = startProgress + (1.0 - startProgress) * t;
      setState(() {
        _progress = target;
        _stageLabel = t >= 1.0 ? 'Ready' : _stageLabel;
      });
      if (t >= 1.0) break;
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  void _dispatch(CrestDestination destination) {
    final coord = _resolvedCoordinator ?? widget.coordinator;
    final ua = _resolvedUserAgent ?? widget.userAgent;

    switch (destination) {
      case OpenNative():
        _swap(const BootScreen());
      case OpenPortal(url: final u, fromColdStartPush: final cold):
        _swap(RidgePortal(url: u, userAgent: ua!, coldStartPush: cold));
      case InviteThenPortal(url: final u):
        _swap(PerchInvite(
          vault: coord!.vault,
          nextPageBuilder: (_) => RidgePortal(url: u, userAgent: ua!),
        ));
      case Unreachable():
        _swap(AirLostPage(
          retryPageBuilder: (_) => AscentSplash(
            // Prefer the resolved coordinator if the pipeline already
            // ran; otherwise fall through to the ready-future path so
            // the retry can also happen before boot has finished.
            coordinator: coord,
            userAgent: ua,
            readyFuture: coord == null ? widget.readyFuture : null,
            initialProgress: _rampCeiling,
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
