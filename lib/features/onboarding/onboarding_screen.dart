import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/fp_feedback.dart';
import '../../core/design/fp_colors.dart';
import '../../core/design/fp_images.dart';
import '../../core/design/fp_tokens.dart';
import '../../core/design/fp_typography.dart';
import '../../data/providers.dart';
import '../../shared/widgets/fp_art.dart';
import '../../shared/widgets/fp_card.dart';
import '../home/home_screen.dart';

class _Page {
  const _Page({
    required this.art,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.accent,
  });

  final String art;
  final String eyebrow;
  final String title;
  final String body;
  final Color accent;
}

const _pages = <_Page>[
  _Page(
    art: FpImages.peakGreen,
    eyebrow: 'Peak',
    title: 'Route and difficulty',
    body:
        'Enter distance, elevation gain, moving time and terrain. Featherpeak '
        'Fury weighs all five factors into one difficulty score and draws the '
        'shape of the climb.',
    accent: FpColors.forest,
  ),
  _Page(
    art: FpImages.featherGreen,
    eyebrow: 'Feather',
    title: 'What you carry',
    body:
        'List your gear by category. The app totals the weight, shows how it '
        'is distributed and compares it against a comfortable range for your '
        'body weight.',
    accent: FpColors.forestMid,
  ),
  _Page(
    art: FpImages.eggSingle,
    eyebrow: 'Egg',
    title: 'Food to bring',
    body:
        'One Egg Unit is one regular meal portion. From moving time, group '
        'size and intensity you get a recommended number of units — you decide '
        'what goes in them.',
    accent: FpColors.goldDeep,
  ),
  _Page(
    art: FpImages.coinStack,
    eyebrow: 'Coin',
    title: 'What it costs',
    body:
        'Add transport, food, parking and gear costs to see the total, the '
        'split per person and where the money actually goes.',
    accent: FpColors.gold,
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _pages.length - 1;

  Future<void> _finish() async {
    FpFeedback.instance.success(FpSound.successfulAction);
    await ref.read(settingsProvider.notifier).completeOnboarding();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    FpFeedback.instance.tap();
    _controller.nextPage(duration: FpMotion.base, curve: FpMotion.curve);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(FpImages.mountainBackdrop, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x22F7F3EA), Color(0xF2F7F3EA)],
                stops: [0.0, 0.55],
              ),
            ),
            child: SizedBox.expand(),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    FpSpace.md,
                    FpSpace.sm,
                    FpSpace.md,
                    0,
                  ),
                  child: Row(
                    children: [
                      FpArt(FpImages.wordmark, size: 132, height: 56),
                      const Spacer(),
                      if (!_isLast)
                        TextButton(
                          onPressed: _finish,
                          child: const Text('Skip'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: (value) => setState(() => _index = value),
                    itemBuilder: (context, index) =>
                        _PageView(page: _pages[index]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(FpSpace.md),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < _pages.length; i++)
                            AnimatedContainer(
                              duration: FpMotion.base,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              height: 6,
                              width: i == _index ? 26 : 6,
                              decoration: BoxDecoration(
                                color: i == _index
                                    ? FpColors.forest
                                    : FpColors.outlineStrong,
                                borderRadius: FpRadius.pillAll,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: FpSpace.md),
                      FilledButton(
                        onPressed: _next,
                        child: Text(_isLast ? 'Start planning' : 'Next'),
                      ),
                      const SizedBox(height: FpSpace.xs),
                      Text(
                        'Everything is calculated on this device. No account, '
                        'no connection needed.',
                        style: FpTypography.caption,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageView extends StatelessWidget {
  const _PageView({required this.page});

  final _Page page;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: FpSpace.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: FpArt(page.art, size: 210, height: 210),
            ),
          ),
          FpCard(
            padding: const EdgeInsets.all(FpSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: page.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: FpSpace.xs),
                    Text(
                      page.eyebrow.toUpperCase(),
                      style: FpTypography.overline.copyWith(color: page.accent),
                    ),
                  ],
                ),
                const SizedBox(height: FpSpace.xs),
                Text(page.title, style: FpTypography.titleLarge),
                const SizedBox(height: FpSpace.xs),
                Text(page.body, style: FpTypography.body),
              ],
            ),
          ),
          const SizedBox(height: FpSpace.md),
        ],
      ),
    );
  }
}
