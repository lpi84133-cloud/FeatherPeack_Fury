import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/fp_colors.dart';
import '../../core/design/fp_images.dart';
import '../../core/design/fp_tokens.dart';
import '../../core/design/fp_typography.dart';
import '../../data/providers.dart';
import '../../shared/widgets/fp_progress_bar.dart';
import '../home/home_screen.dart';
import '../onboarding/onboarding_screen.dart';
import 'boot_controller.dart';

/// The launch screen. It shows the portrait or the landscape artwork depending
/// on how the device is held, and its bar tracks the real initialisation work.
class BootScreen extends ConsumerStatefulWidget {
  const BootScreen({super.key});

  @override
  ConsumerState<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends ConsumerState<BootScreen> {
  /// Long enough for the filled bar to be seen at 100%, short enough that it is
  /// not padding.
  static const _handoff = Duration(milliseconds: 260);

  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Only the launch screen accepts landscape; the app itself is portrait.
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      if (!mounted) return;
      await ref.read(bootProvider.notifier).start(context);
    });
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;

    await Future<void>.delayed(_handoff);
    if (!mounted) return;
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    if (!mounted) return;

    final seenOnboarding = ref.read(settingsProvider).onboardingSeen;
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: FpMotion.slow,
        pageBuilder: (_, _, _) =>
            seenOnboarding ? const HomeScreen() : const OnboardingScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final boot = ref.watch(bootProvider);
    if (boot.isFinished) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _leave());
    }

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
                alignment: isLandscape ? Alignment.center : Alignment.topCenter,
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
                    horizontal: isLandscape ? FpSpace.xxl : FpSpace.lg,
                    vertical: FpSpace.lg,
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: _BootFooter(state: boot, compact: isLandscape),
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

class _BootFooter extends StatelessWidget {
  const _BootFooter({required this.state, required this.compact});

  final BootState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final percent = (state.progress * 100).floor().clamp(0, 100);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                state.isFinished ? 'Ready' : state.stage.label,
                style: FpTypography.label.copyWith(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: FpSpace.sm),
            Text(
              '$percent%',
              style: FpTypography.metricSmall.copyWith(
                color: Colors.white,
                fontSize: compact ? 18 : 20,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? FpSpace.xs : FpSpace.sm),
        FpProgressBar(value: state.progress, height: compact ? 10 : 14),
        SizedBox(height: compact ? FpSpace.xs : FpSpace.sm),
        Text(
          'Works fully offline · No account required',
          style: FpTypography.caption.copyWith(color: const Color(0xCCFFFFFF)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
