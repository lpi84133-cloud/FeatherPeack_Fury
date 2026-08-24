import 'package:flutter/material.dart';

import '../../core/design/fp_colors.dart';
import '../../core/design/fp_tokens.dart';
import '../../core/design/fp_typography.dart';

/// Section header built from a short uppercase eyebrow and a rule that runs to
/// the edge of the content column, echoing a trail line on a map.
class FpSectionHeader extends StatelessWidget {
  const FpSectionHeader({
    required this.label,
    this.trailing,
    super.key,
  });

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label.toUpperCase(), style: FpTypography.overline),
        const SizedBox(width: FpSpace.sm),
        const Expanded(child: Divider(color: FpColors.outline)),
        if (trailing != null) ...[
          const SizedBox(width: FpSpace.sm),
          trailing!,
        ],
      ],
    );
  }
}
