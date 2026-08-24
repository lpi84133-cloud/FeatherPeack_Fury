import 'package:flutter/material.dart';

import '../../core/design/fp_colors.dart';
import '../../core/design/fp_tokens.dart';
import '../../core/design/fp_typography.dart';
import 'fp_art.dart';
import 'fp_card.dart';

/// One number with its label and, where it helps, the themed object that stands
/// for it.
class FpMetricTile extends StatelessWidget {
  const FpMetricTile({
    required this.label,
    required this.value,
    this.art,
    this.icon,
    this.accent = FpColors.forest,
    this.footnote,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final String? art;
  final IconData? icon;
  final Color accent;
  final String? footnote;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FpCard(
      onTap: onTap,
      padding: const EdgeInsets.all(FpSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (art != null)
                FpArt(art!, size: 26)
              else if (icon != null)
                Icon(icon, size: 20, color: accent),
              if (art != null || icon != null) const SizedBox(width: FpSpace.xs),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: FpTypography.overline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: FpSpace.xs),
          Text(
            value,
            style: FpTypography.metricSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (footnote != null) ...[
            const SizedBox(height: 2),
            Text(
              footnote!,
              style: FpTypography.caption.copyWith(fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// Label on the left, value on the right — the workhorse row of the app.
class FpValueRow extends StatelessWidget {
  const FpValueRow({
    required this.label,
    required this.value,
    this.art,
    this.icon,
    this.valueColor,
    this.dense = false,
    super.key,
  });

  final String label;
  final String value;
  final String? art;
  final IconData? icon;
  final Color? valueColor;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 5 : FpSpace.xs),
      child: Row(
        children: [
          if (art != null) ...[
            FpArt(art!, size: 24),
            const SizedBox(width: FpSpace.xs),
          ] else if (icon != null) ...[
            Icon(icon, size: 18, color: FpColors.graphiteSoft),
            const SizedBox(width: FpSpace.xs),
          ],
          Expanded(child: Text(label, style: FpTypography.body)),
          const SizedBox(width: FpSpace.xs),
          Text(
            value,
            style: FpTypography.bodyStrong.copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }
}

/// Proportional bar used for load and budget distribution.
class FpShareBar extends StatelessWidget {
  const FpShareBar({
    required this.share,
    this.color = FpColors.forest,
    this.height = 8,
    this.background = FpColors.surfaceAlt,
    super.key,
  });

  final double share;
  final Color color;
  final double height;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Container(height: height, color: background),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: share.clamp(0.0, 1.0)),
              duration: FpMotion.slow,
              curve: FpMotion.curve,
              builder: (context, value, _) => Container(
                height: height,
                width: constraints.maxWidth * value,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small rounded tag for tiers, severities and states.
class FpTag extends StatelessWidget {
  const FpTag({
    required this.label,
    this.color = FpColors.forest,
    this.filled = false,
    super.key,
  });

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.12),
        borderRadius: FpRadius.pillAll,
        border: filled ? null : Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: FpTypography.label.copyWith(
          color: filled ? Colors.white : color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Explains why a number is partial instead of pretending it is complete.
class FpNotice extends StatelessWidget {
  const FpNotice({
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.color = FpColors.skyDeep,
    super.key,
  });

  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(FpSpace.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: FpRadius.tileAll,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: FpSpace.xs),
          Expanded(
            child: Text(
              message,
              style: FpTypography.caption.copyWith(color: FpColors.graphiteMid),
            ),
          ),
        ],
      ),
    );
  }
}
