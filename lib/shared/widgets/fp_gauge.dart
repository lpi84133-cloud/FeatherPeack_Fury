import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design/fp_colors.dart';
import '../../core/design/fp_tokens.dart';
import '../../core/design/fp_typography.dart';
import 'fp_art.dart';

/// Open-ended arc used for the difficulty score. The gap at the bottom is where
/// the label sits, so the gauge reads as one object rather than a ring plus text.
class FpArcGauge extends StatelessWidget {
  const FpArcGauge({
    required this.value,
    required this.label,
    required this.caption,
    required this.color,
    this.art,
    this.size = 168,
    super.key,
  });

  /// 0..1 fill of the arc.
  final double value;
  final String label;
  final String caption;
  final Color color;
  final String? art;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: FpMotion.slow,
        curve: FpMotion.curve,
        builder: (context, animated, _) => CustomPaint(
          painter: _ArcPainter(value: animated, color: color),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (art != null) ...[
                  FpArt(art!, size: size * 0.26),
                  const SizedBox(height: 2),
                ],
                Text(
                  label,
                  style: FpTypography.heroMetric.copyWith(
                    fontSize: size * 0.26,
                    color: FpColors.graphite,
                  ),
                ),
                Text(caption, style: FpTypography.caption),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.value, required this.color});

  final double value;
  final Color color;

  static const _startAngle = math.pi * 0.75;
  static const _sweep = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = FpColors.surfaceAlt;

    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: _startAngle,
        endAngle: _startAngle + _sweep,
        colors: [color.withValues(alpha: 0.55), color],
        transform: GradientRotation(_startAngle),
      ).createShader(rect);

    canvas.drawArc(rect, _startAngle, _sweep, false, track);
    if (value > 0) {
      canvas.drawArc(rect, _startAngle, _sweep * value, false, fill);
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.value != value || old.color != color;
}
