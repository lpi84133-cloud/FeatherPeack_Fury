import 'package:flutter/material.dart';

import '../../core/audio/fp_feedback.dart';
import '../../core/design/fp_colors.dart';
import '../../core/design/fp_tokens.dart';
import '../../core/design/fp_typography.dart';

/// Circular icon button used instead of the stock app-bar actions, so the
/// chrome stays consistent with the rounded card language.
class FpRoundButton extends StatelessWidget {
  const FpRoundButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.background = FpColors.surface,
    this.foreground = FpColors.graphite,
    this.size = 42,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color background;
  final Color foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: size,
      height: size,
      child: Material(
        color: background,
        shape: const CircleBorder(
          side: BorderSide(color: FpColors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed == null
              ? null
              : () {
                  FpFeedback.instance.tap();
                  onPressed!();
                },
          child: Icon(icon, size: size * 0.46, color: foreground),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Screen chrome for every page except the launch screen: a floating header row
/// over the cream canvas, with no Material app bar.
class FpScreen extends StatelessWidget {
  const FpScreen({
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.onBack,
    this.showBack = true,
    this.bottomBar,
    this.padding = const EdgeInsets.symmetric(horizontal: FpSpace.md),
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final bool showBack;
  final Widget? bottomBar;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FpSpace.md,
                FpSpace.xs,
                FpSpace.md,
                FpSpace.sm,
              ),
              child: Row(
                children: [
                  if (showBack) ...[
                    FpRoundButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onPressed: () {
                        FpFeedback.instance.play(FpSound.screenBack);
                        (onBack ?? Navigator.of(context).pop)();
                      },
                    ),
                    const SizedBox(width: FpSpace.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: FpTypography.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: FpTypography.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  for (final action in actions) ...[
                    const SizedBox(width: FpSpace.xs),
                    action,
                  ],
                ],
              ),
            ),
            Expanded(
              child: Padding(padding: padding, child: child),
            ),
            if (bottomBar != null)
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: FpColors.canvas,
                  border: Border(top: BorderSide(color: FpColors.outline)),
                ),
                padding: EdgeInsets.fromLTRB(
                  FpSpace.md,
                  FpSpace.sm,
                  FpSpace.md,
                  FpSpace.sm + MediaQuery.paddingOf(context).bottom,
                ),
                child: bottomBar,
              )
            else
              SizedBox(height: MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ),
    );
  }
}
