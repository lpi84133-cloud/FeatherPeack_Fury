import 'package:flutter/material.dart';

import '../../core/design/fp_tokens.dart';
import '../../core/design/fp_typography.dart';
import 'fp_art.dart';

/// Empty states always say what is missing and offer the action that fixes it,
/// so no screen is ever just decoration.
class FpEmptyState extends StatelessWidget {
  const FpEmptyState({
    required this.art,
    required this.title,
    required this.message,
    this.action,
    this.artSize = 200,
    super.key,
  });

  final String art;
  final String title;
  final String message;
  final Widget? action;
  final double artSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FpArt(art, size: artSize, height: artSize),
            const SizedBox(height: FpSpace.md),
            Text(
              title,
              style: FpTypography.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: FpSpace.xs),
            Text(message, style: FpTypography.body, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: FpSpace.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
