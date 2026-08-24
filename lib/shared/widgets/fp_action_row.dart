import 'package:flutter/material.dart';

import '../../core/design/fp_colors.dart';
import '../../core/design/fp_tokens.dart';
import '../../core/design/fp_typography.dart';
import 'fp_screen.dart';

/// Tappable row used in sheets and cards. It carries its own Material so ink
/// and highlights land on top of the surrounding card decoration instead of
/// being hidden behind it.
class FpActionRow extends StatelessWidget {
  const FpActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.description,
    this.color = FpColors.forest,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String label;
  final String? description;
  final VoidCallback onTap;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FpSpace.md,
            vertical: FpSpace.sm,
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: FpSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: FpTypography.bodyStrong),
                    if (description != null)
                      Text(description!, style: FpTypography.caption),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Switch row that behaves like a list tile but carries its own Material, for
/// the same reason as [FpActionRow].
class FpSwitchRow extends StatelessWidget {
  const FpSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
    super.key,
  });

  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FpSpace.xs,
            vertical: FpSpace.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: FpTypography.bodyStrong),
                    if (description != null) ...[
                      const SizedBox(height: 2),
                      Text(description!, style: FpTypography.caption),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: FpSpace.sm),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header for a modal sheet: grab handle, title and an optional explanation.
class FpSheetHeader extends StatelessWidget {
  const FpSheetHeader({required this.title, this.description, super.key});

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FpSpace.md,
        FpSpace.md,
        FpSpace.md,
        FpSpace.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(bottom: FpSpace.sm),
            decoration: BoxDecoration(
              color: FpColors.outlineStrong,
              borderRadius: FpRadius.pillAll,
            ),
          ),
          Text(title, style: FpTypography.titleLarge),
          if (description != null) ...[
            const SizedBox(height: 2),
            Text(description!, style: FpTypography.caption),
          ],
        ],
      ),
    );
  }
}

/// Form sheet with a scrolling body and a confirm button pinned to the bottom,
/// so the action stays reachable no matter how tall the form or the keyboard is.
class FpFormSheet extends StatelessWidget {
  const FpFormSheet({
    required this.title,
    required this.fields,
    required this.actionLabel,
    required this.onSubmit,
    this.description,
    super.key,
  });

  final String title;
  final String? description;
  final List<Widget> fields;
  final String actionLabel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FpSheetHeader(title: title, description: description),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  top: FpSpace.lg,
                  right: FpSpace.md,
                ),
                child: FpRoundButton(
                  icon: Icons.close_rounded,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                FpSpace.md,
                FpSpace.xs,
                FpSpace.md,
                FpSpace.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: fields,
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: FpColors.outline)),
            ),
            padding: EdgeInsets.fromLTRB(
              FpSpace.md,
              FpSpace.sm,
              FpSpace.md,
              FpSpace.sm + insets + MediaQuery.paddingOf(context).bottom,
            ),
            child: FilledButton(onPressed: onSubmit, child: Text(actionLabel)),
          ),
        ],
      ),
    );
  }
}
