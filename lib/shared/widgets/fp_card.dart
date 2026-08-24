import 'package:flutter/material.dart';

import '../../core/design/fp_colors.dart';
import '../../core/design/fp_tokens.dart';

/// The single card primitive used across the app: soft rounding, hairline
/// outline and a low shadow. Tapping is optional so the same shape serves both
/// static panels and navigation tiles.
class FpCard extends StatelessWidget {
  const FpCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(FpSpace.md),
    this.color = FpColors.surface,
    this.borderRadius = FpRadius.cardAll,
    this.border = FpBorders.hairline,
    this.shadow = FpShadow.soft,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color color;
  final BorderRadius borderRadius;
  final BorderSide border;
  final List<BoxShadow> shadow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: Border.fromBorderSide(border),
        boxShadow: shadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
