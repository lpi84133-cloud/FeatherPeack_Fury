import 'package:flutter/material.dart';

import '../../core/design/fp_colors.dart';
import '../../core/design/fp_tokens.dart';

/// A left-to-right fill bar. The animation only ever chases the value it was
/// given — it never advances on its own.
class FpProgressBar extends StatelessWidget {
  const FpProgressBar({
    required this.value,
    this.height = 12,
    this.trackColor = const Color(0x33FFFFFF),
    this.gradient = const [FpColors.goldSoft, FpColors.gold],
    this.animate = true,
    super.key,
  });

  final double value;
  final double height;
  final Color trackColor;
  final List<Color> gradient;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);

    Widget fill(double fraction) => LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Container(
            height: height,
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(height),
            ),
          ),
          Container(
            height: height,
            width: constraints.maxWidth * fraction,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(height),
            ),
          ),
        ],
      ),
    );

    if (!animate) return fill(clamped);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: clamped),
      duration: FpMotion.base,
      curve: Curves.easeOut,
      builder: (context, animated, _) => fill(animated),
    );
  }
}
