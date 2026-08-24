import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/audio/fp_feedback.dart';
import '../../core/design/fp_colors.dart';
import '../../core/design/fp_tokens.dart';
import '../../core/design/fp_typography.dart';
import 'fp_art.dart';

/// Field label with the unit spelled out, so a form never asks for an
/// ambiguous number.
class FpFieldLabel extends StatelessWidget {
  const FpFieldLabel({required this.text, this.unit, this.optional = false, super.key});

  final String text;
  final String? unit;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FpSpace.xxs, left: 2),
      child: Row(
        children: [
          Text(
            unit == null ? text : '$text, $unit',
            style: FpTypography.label.copyWith(color: FpColors.graphite),
          ),
          if (optional) ...[
            const SizedBox(width: FpSpace.xxs),
            Text('optional', style: FpTypography.caption),
          ],
        ],
      ),
    );
  }
}

/// Numeric entry that treats an empty field as "not provided" rather than zero,
/// which is what keeps partial trips honest downstream.
class FpNumberField extends StatefulWidget {
  const FpNumberField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.unit,
    this.hint,
    this.optional = false,
    this.decimals = 1,
    this.max,
    super.key,
  });

  final String label;
  final double? value;
  final ValueChanged<double?> onChanged;
  final String? unit;
  final String? hint;
  final bool optional;
  final int decimals;
  final double? max;

  @override
  State<FpNumberField> createState() => _FpNumberFieldState();
}

class _FpNumberFieldState extends State<FpNumberField> {
  late final TextEditingController _controller = TextEditingController(
    text: _text(widget.value),
  );

  String _text(double? value) {
    if (value == null) return '';
    if (widget.decimals == 0) return value.round().toString();
    final text = value.toStringAsFixed(widget.decimals);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  @override
  void didUpdateWidget(FpNumberField old) {
    super.didUpdateWidget(old);
    // Only reset the field when the value changed elsewhere, never while typing.
    if (widget.value != old.value &&
        double.tryParse(_controller.text.replaceAll(',', '.')) != widget.value) {
      _controller.text = _text(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FpFieldLabel(
          text: widget.label,
          unit: widget.unit,
          optional: widget.optional,
        ),
        TextField(
          controller: _controller,
          keyboardType: widget.decimals == 0
              ? TextInputType.number
              : const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          autofillHints: const [],
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            LengthLimitingTextInputFormatter(8),
          ],
          decoration: InputDecoration(
            hintText: widget.hint ?? '0',
            isDense: true,
            suffixText: widget.unit,
            suffixStyle: FpTypography.label,
          ),
          style: FpTypography.bodyStrong,
          onChanged: (raw) {
            final text = raw.replaceAll(',', '.').trim();
            if (text.isEmpty) {
              widget.onChanged(null);
              return;
            }
            final parsed = double.tryParse(text);
            if (parsed == null || parsed < 0) return;
            widget.onChanged(widget.max == null ? parsed : parsed.clamp(0, widget.max!));
          },
        ),
      ],
    );
  }
}

/// Hours and minutes side by side. Duration is entered as moving time, which is
/// the figure the food estimate needs.
class FpDurationField extends StatefulWidget {
  const FpDurationField({
    required this.minutes,
    required this.onChanged,
    this.label = 'Moving time',
    super.key,
  });

  final int? minutes;
  final ValueChanged<int?> onChanged;
  final String label;

  @override
  State<FpDurationField> createState() => _FpDurationFieldState();
}

class _FpDurationFieldState extends State<FpDurationField> {
  late final TextEditingController _hours = TextEditingController(
    text: widget.minutes == null ? '' : (widget.minutes! ~/ 60).toString(),
  );
  late final TextEditingController _minutes = TextEditingController(
    text: widget.minutes == null || widget.minutes! % 60 == 0
        ? ''
        : (widget.minutes! % 60).toString(),
  );

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  void _emit() {
    final hours = int.tryParse(_hours.text);
    final minutes = int.tryParse(_minutes.text);
    if (hours == null && minutes == null) {
      widget.onChanged(null);
      return;
    }
    widget.onChanged((hours ?? 0) * 60 + (minutes ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    Widget field({
      required TextEditingController controller,
      required String hint,
      required String suffix,
      required int maxLength,
    }) {
      return Expanded(
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofillHints: const [],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(maxLength),
          ],
          decoration: InputDecoration(
            hintText: hint,
            suffixText: suffix,
            isDense: true,
          ),
          style: FpTypography.bodyStrong,
          onChanged: (_) => _emit(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FpFieldLabel(text: widget.label),
        Row(
          children: [
            field(
              controller: _hours,
              hint: '0',
              suffix: 'h',
              maxLength: 3,
            ),
            const SizedBox(width: FpSpace.xs),
            field(
              controller: _minutes,
              hint: '00',
              suffix: 'm',
              maxLength: 2,
            ),
          ],
        ),
      ],
    );
  }
}

/// Plus/minus control for small integer counts such as group size.
class FpStepper extends StatelessWidget {
  const FpStepper({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 40,
    super.key,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, int next, bool enabled) {
      return SizedBox(
        width: 38,
        height: 38,
        child: Material(
          color: enabled ? FpColors.forestTint : FpColors.surfaceAlt,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled
                ? () {
                    FpFeedback.instance.tap();
                    onChanged(next);
                  }
                : null,
            child: Icon(
              icon,
              size: 18,
              color: enabled ? FpColors.forest : FpColors.graphiteSoft,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FpFieldLabel(text: label),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: FpSpace.xxs),
          decoration: BoxDecoration(
            color: FpColors.surface,
            borderRadius: FpRadius.tileAll,
            border: Border.fromBorderSide(FpBorders.hairline),
          ),
          child: Row(
            children: [
              button(Icons.remove_rounded, value - 1, value > min),
              Expanded(
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: FpTypography.metricSmall.copyWith(fontSize: 18),
                ),
              ),
              button(Icons.add_rounded, value + 1, value < max),
            ],
          ),
        ),
      ],
    );
  }
}

/// Selectable options laid out as a wrap, optionally with the themed artwork for
/// each choice.
class FpChoiceGroup<T> extends StatelessWidget {
  const FpChoiceGroup({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.artFor,
    this.optional = false,
    super.key,
  });

  final String label;
  final List<(T, String)> options;
  final T? selected;
  final ValueChanged<T> onChanged;
  final String? Function(T value)? artFor;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FpFieldLabel(text: label, optional: optional),
        Wrap(
          spacing: FpSpace.xs,
          runSpacing: FpSpace.xs,
          children: [
            for (final (value, text) in options)
              _Choice(
                text: text,
                art: artFor?.call(value),
                isSelected: value == selected,
                onTap: () {
                  FpFeedback.instance.tap();
                  onChanged(value);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.text,
    required this.isSelected,
    required this.onTap,
    this.art,
  });

  final String text;
  final bool isSelected;
  final VoidCallback onTap;
  final String? art;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? FpColors.forestTint : FpColors.surface,
      borderRadius: FpRadius.pillAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: FpMotion.fast,
          padding: EdgeInsets.fromLTRB(art == null ? 14 : 8, 8, 14, 8),
          decoration: BoxDecoration(
            borderRadius: FpRadius.pillAll,
            border: Border.all(
              color: isSelected ? FpColors.forest : FpColors.outline,
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (art != null) ...[
                FpArt(art!, size: 26),
                const SizedBox(width: 6),
              ],
              Text(
                text,
                style: FpTypography.bodyStrong.copyWith(
                  color: isSelected ? FpColors.forestDeep : FpColors.graphiteMid,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
