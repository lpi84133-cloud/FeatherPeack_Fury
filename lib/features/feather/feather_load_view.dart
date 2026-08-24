import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/audio/fp_feedback.dart';
import '../../core/design/fp_colors.dart';
import '../../core/design/fp_images.dart';
import '../../core/design/fp_tokens.dart';
import '../../core/design/fp_typography.dart';
import '../../data/providers.dart';
import '../../domain/calc/fury_zones.dart';
import '../../domain/calc/load_breakdown.dart';
import '../../domain/calc/trip_analysis.dart';
import '../../domain/models/trip.dart';
import '../../shared/widgets/fp_action_row.dart';
import '../../shared/widgets/fp_art.dart';
import '../../shared/widgets/fp_card.dart';
import '../../shared/widgets/fp_inputs.dart';
import '../../shared/widgets/fp_metric.dart';
import '../../shared/widgets/fp_section_header.dart';
import '../trip/create_trip_screen.dart';

const _uuid = Uuid();

Color _sliceColor(LoadSlice slice) => switch (slice) {
  LoadSlice.water => FpColors.skyDeep,
  LoadSlice.food => FpColors.goldDeep,
  LoadSlice.clothing => FpColors.forestMid,
  LoadSlice.health => FpColors.severe,
  LoadSlice.equipment => FpColors.forest,
  LoadSlice.electronics => FpColors.graphiteMid,
  LoadSlice.other => FpColors.forestSoft,
  LoadSlice.pack => FpColors.outlineStrong,
};

/// Feather Load: what the pack weighs, how it is distributed and how that
/// compares to a comfortable load for this hiker.
class FeatherLoadView extends ConsumerWidget {
  const FeatherLoadView({required this.analysis, super.key});

  final TripAnalysis analysis;

  Future<void> _editItem(
    BuildContext context,
    WidgetRef ref, {
    GearItem? existing,
  }) async {
    final format = ref.read(formatProvider);
    final result = await showModalBottomSheet<GearItem>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _GearSheet(
        existing: existing,
        weightSymbol: format.weightSymbol,
        toKg: format.weightToKg,
        fromKg: format.kgToWeight,
      ),
    );
    if (result == null) return;

    final trip = analysis.trip;
    final gear = [...trip.gear];
    final index = gear.indexWhere((item) => item.id == result.id);
    if (index == -1) {
      gear.add(result);
      FpFeedback.instance.success(FpSound.addItem);
    } else {
      gear[index] = result;
      FpFeedback.instance.success(FpSound.successfulAction);
    }
    await ref.read(tripsProvider.notifier).save(trip.copyWith(gear: gear));
  }

  Future<void> _removeItem(WidgetRef ref, GearItem item) async {
    final trip = analysis.trip;
    FpFeedback.instance.play(FpSound.removeItem);
    await ref.read(tripsProvider.notifier).save(
      trip.copyWith(
        gear: trip.gear.where((entry) => entry.id != item.id).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final load = analysis.load;
    final format = ref.watch(formatProvider);
    final profile = ref.watch(profileProvider);
    final trip = analysis.trip;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(
            FpSpace.md,
            0,
            FpSpace.md,
            FpSpace.xxl + FpSpace.xl,
          ),
          children: [
            FpCard(
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FpArt(FpImages.featherGreen, size: 56, height: 78),
                      const SizedBox(width: FpSpace.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('TOTAL LOAD', style: FpTypography.overline),
                            Text(
                              format.weight(load.totalKg),
                              style: FpTypography.metric,
                            ),
                            Text(
                              load.totalKg == 0
                                  ? 'Nothing listed yet'
                                  : '${load.bodySharePercent.round()}% of your '
                                        '${format.weight(profile.bodyWeightKg)} '
                                        'body weight',
                              style: FpTypography.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: FpSpace.md),
                  _LoadRangeBar(load: load),
                ],
              ),
            ),
            _WaterCard(analysis: analysis),
            if (load.totalKg == 0) ...[
              const SizedBox(height: FpSpace.md),
              FpCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Start with the pack', style: FpTypography.title),
                    const SizedBox(height: FpSpace.xxs),
                    Text(
                      'Enter the weight of the pack itself in the trip '
                      'parameters, then itemise what goes inside. Water is '
                      'counted automatically.',
                      style: FpTypography.body,
                    ),
                    const SizedBox(height: FpSpace.sm),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CreateTripScreen(existing: trip),
                        ),
                      ),
                      child: const Text('Set base pack weight'),
                    ),
                  ],
                ),
              ),
            ],
            if (load.portions.isNotEmpty) ...[
              const SizedBox(height: FpSpace.md),
              const FpSectionHeader(label: 'Distribution'),
              const SizedBox(height: FpSpace.xs),
              FpCard(
                child: Column(
                  children: [
                    for (final portion in load.portions) ...[
                      _PortionRow(portion: portion),
                      if (portion != load.portions.last)
                        const SizedBox(height: FpSpace.sm),
                    ],
                  ],
                ),
              ),
            ],
            if (load.dominantPortion != null) ...[
              const SizedBox(height: FpSpace.sm),
              FpNotice(
                message:
                    '${load.dominantPortion!.slice.label} takes '
                    '${(load.dominantPortion!.share * 100).round()}% of the '
                    'pack. Not a problem by itself, but worth a second look.',
                icon: Icons.balance_rounded,
                color: FpColors.hard,
              ),
            ],
            const SizedBox(height: FpSpace.md),
            FpSectionHeader(
              label: 'Itemised gear · ${trip.gear.length}',
              trailing: TextButton.icon(
                onPressed: () => _editItem(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
              ),
            ),
            const SizedBox(height: FpSpace.xs),
            if (trip.gear.isEmpty)
              FpCard(
                child: Row(
                  children: [
                    const FpArt(FpImages.gearBackpack, size: 44),
                    const SizedBox(width: FpSpace.sm),
                    Expanded(
                      child: Text(
                        'No items listed. Adding them is what turns a single '
                        'total into a balance check.',
                        style: FpTypography.body,
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final category in GearCategory.values)
                _CategoryGroup(
                  category: category,
                  items: trip.gear
                      .where((item) => item.category == category)
                      .toList(),
                  onEdit: (item) => _editItem(context, ref, existing: item),
                  onRemove: (item) => _removeItem(ref, item),
                ),
            const SizedBox(height: FpSpace.md),
            FpNotice(
              message:
                  'The comfortable range comes from your body weight in '
                  'Profile (${format.weight(profile.bodyWeightKg)}). Change it '
                  'there and every trip updates.',
            ),
          ],
        ),
        Positioned(
          right: FpSpace.md,
          bottom: FpSpace.md,
          child: FloatingActionButton.small(
            onPressed: () => _editItem(context, ref),
            backgroundColor: FpColors.forest,
            foregroundColor: Colors.white,
            tooltip: 'Add gear item',
            child: const Icon(Icons.add_rounded),
          ),
        ),
      ],
    );
  }
}

/// Water recommendation derived from the same 0.4 L/person/hour constant that
/// Fury Zones uses, displayed as a progress bar so the user can see at a glance
/// whether the volume they entered covers the trip.
class _WaterCard extends ConsumerWidget {
  const _WaterCard({required this.analysis});

  final TripAnalysis analysis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = analysis.trip;
    final hours = trip.movingHours;
    if (hours == null || hours <= 0) return const SizedBox.shrink();

    final format = ref.watch(formatProvider);
    final recommended =
        FuryResult.waterPerPersonPerHourLitres * hours * trip.people;
    final entered = trip.waterLitres ?? 0.0;
    final share = (entered / recommended).clamp(0.0, 1.0);

    // 10 % tolerance so a litre rounded down does not look alarming.
    final isOk = entered >= recommended * 0.9;
    final hasEntry = trip.waterLitres != null && trip.waterLitres! > 0;

    final Color barColor;
    final String verdict;
    if (!hasEntry) {
      barColor = FpColors.outlineStrong;
      verdict = 'Not entered';
    } else if (isOk) {
      barColor = FpColors.skyDeep;
      verdict = 'Looks good';
    } else {
      barColor = FpColors.hard;
      verdict = 'Below estimate';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: FpSpace.md),
        const FpSectionHeader(label: 'Water'),
        const SizedBox(height: FpSpace.xs),
        FpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('RECOMMENDED', style: FpTypography.overline),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            format.volume(recommended),
                            style: FpTypography.metric,
                          ),
                        ],
                      ),
                      Text(
                        '${format.volume(FuryResult.waterPerPersonPerHourLitres)}'
                        '/person/h · ${hours.toStringAsFixed(1)} h'
                        ' · ${trip.people}'
                        ' ${trip.people == 1 ? 'person' : 'people'}',
                        style: FpTypography.caption,
                      ),
                    ],
                  ),
                  const Spacer(),
                  const FpArt(FpImages.gearBottle, size: 48, height: 62),
                ],
              ),
              const SizedBox(height: FpSpace.sm),
              FpShareBar(share: share, color: barColor, height: 6),
              const SizedBox(height: FpSpace.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      hasEntry
                          ? 'Entered: ${format.volume(trip.waterLitres)}'
                          : 'No volume entered yet',
                      style: FpTypography.caption,
                    ),
                  ),
                  FpTag(label: verdict, color: barColor),
                ],
              ),
              if (!isOk || !hasEntry) ...[
                const SizedBox(height: FpSpace.sm),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CreateTripScreen(existing: trip),
                    ),
                  ),
                  icon: const Icon(Icons.water_drop_outlined, size: 18),
                  label: const Text('Set water volume'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Shows the load against the comfortable, recommended and heavy thresholds so
/// the number has context instead of standing alone.
class _LoadRangeBar extends ConsumerWidget {
  const _LoadRangeBar({required this.load});

  final LoadResult load;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final format = ref.watch(formatProvider);
    final ceiling = (load.heavyKg * 1.25).clamp(1.0, double.infinity);
    final position = (load.totalKg / ceiling).clamp(0.0, 1.0);

    final Color color;
    final String verdict;
    if (load.totalKg == 0) {
      color = FpColors.outlineStrong;
      verdict = 'No load entered';
    } else if (load.isHeavy) {
      color = FpColors.severe;
      verdict = 'Above the heavy threshold';
    } else if (load.isOverRecommended) {
      color = FpColors.hard;
      verdict = 'Above the comfortable range';
    } else if (load.totalKg >= load.comfortableKg) {
      color = FpColors.easy;
      verdict = 'Inside the comfortable range';
    } else {
      color = FpColors.easy;
      verdict = 'Light load';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return SizedBox(
              height: 30,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 11,
                    left: 0,
                    right: 0,
                    child: ClipRRect(
                      borderRadius: FpRadius.pillAll,
                      child: Row(
                        children: [
                          Expanded(
                            flex: (load.comfortableKg / ceiling * 1000).round(),
                            child: Container(height: 8, color: FpColors.easy),
                          ),
                          Expanded(
                            flex:
                                ((load.recommendedMaxKg - load.comfortableKg) /
                                        ceiling *
                                        1000)
                                    .round(),
                            child: Container(
                              height: 8,
                              color: FpColors.goldSoft,
                            ),
                          ),
                          Expanded(
                            flex:
                                ((load.heavyKg - load.recommendedMaxKg) /
                                        ceiling *
                                        1000)
                                    .round(),
                            child: Container(height: 8, color: FpColors.hard),
                          ),
                          Expanded(
                            flex: ((ceiling - load.heavyKg) / ceiling * 1000)
                                .round(),
                            child: Container(height: 8, color: FpColors.severe),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: (width * position - 7).clamp(0.0, width - 14),
                    top: 4,
                    child: Container(
                      width: 14,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: FpRadius.pillAll,
                        border: Border.all(color: FpColors.graphite, width: 2),
                        boxShadow: FpShadow.soft,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: FpSpace.xs),
        Row(
          children: [
            Expanded(
              child: Text(
                'Comfortable up to ${format.weight(load.recommendedMaxKg)}',
                style: FpTypography.caption,
              ),
            ),
            FpTag(label: verdict, color: color),
          ],
        ),
      ],
    );
  }
}

class _PortionRow extends ConsumerWidget {
  const _PortionRow({required this.portion});

  final LoadPortion portion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final format = ref.watch(formatProvider);
    return Column(
      children: [
        Row(
          children: [
            FpArt(portion.slice.image, size: 26),
            const SizedBox(width: FpSpace.xs),
            Expanded(
              child: Text(portion.slice.label, style: FpTypography.body),
            ),
            Text(
              format.weight(portion.weightKg),
              style: FpTypography.bodyStrong,
            ),
            const SizedBox(width: FpSpace.xs),
            SizedBox(
              width: 38,
              child: Text(
                '${(portion.share * 100).round()}%',
                textAlign: TextAlign.right,
                style: FpTypography.label,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        FpShareBar(share: portion.share, color: _sliceColor(portion.slice)),
      ],
    );
  }
}

class _CategoryGroup extends ConsumerWidget {
  const _CategoryGroup({
    required this.category,
    required this.items,
    required this.onEdit,
    required this.onRemove,
  });

  final GearCategory category;
  final List<GearItem> items;
  final ValueChanged<GearItem> onEdit;
  final ValueChanged<GearItem> onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();
    final format = ref.watch(formatProvider);
    final total = items.fold<double>(0, (sum, item) => sum + item.totalKg);

    return Padding(
      padding: const EdgeInsets.only(bottom: FpSpace.xs),
      child: FpCard(
        padding: const EdgeInsets.symmetric(
          horizontal: FpSpace.sm,
          vertical: FpSpace.xs,
        ),
        child: Column(
          children: [
            Row(
              children: [
                FpArt(category.image, size: 28),
                const SizedBox(width: FpSpace.xs),
                Expanded(
                  child: Text(
                    category.label.toUpperCase(),
                    style: FpTypography.overline,
                  ),
                ),
                Text(format.weight(total), style: FpTypography.label),
              ],
            ),
            for (final item in items)
              Dismissible(
                key: ValueKey(item.id),
                direction: DismissDirection.endToStart,
                background: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: FpSpace.xs),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: FpColors.severe,
                    ),
                  ),
                ),
                onDismissed: (_) => onRemove(item),
                child: InkWell(
                  onTap: () => onEdit(item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.quantity > 1
                                ? '${item.name} × ${item.quantity}'
                                : item.name,
                            style: FpTypography.body,
                          ),
                        ),
                        Text(
                          format.weight(item.totalKg),
                          style: FpTypography.bodyStrong,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GearSheet extends StatefulWidget {
  const _GearSheet({
    required this.weightSymbol,
    required this.toKg,
    required this.fromKg,
    this.existing,
  });

  final GearItem? existing;
  final String weightSymbol;
  final double Function(double) toKg;
  final double Function(double) fromKg;

  @override
  State<_GearSheet> createState() => _GearSheetState();
}

class _GearSheetState extends State<_GearSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late GearCategory _category =
      widget.existing?.category ?? GearCategory.equipment;
  late double? _weight = widget.existing == null
      ? null
      : widget.fromKg(widget.existing!.weightKg);
  late int _quantity = widget.existing?.quantity ?? 1;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty || _weight == null || _weight == 0) {
      FpFeedback.instance.warn();
      return;
    }
    Navigator.pop(
      context,
      GearItem(
        id: widget.existing?.id ?? _uuid.v4(),
        name: name,
        category: _category,
        weightKg: widget.toKg(_weight!),
        quantity: _quantity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;

    return FpFormSheet(
      title: isNew ? 'Add gear' : 'Edit gear',
      description: 'Weight is per item; quantity multiplies it.',
      actionLabel: isNew ? 'Add to pack' : 'Save item',
      onSubmit: _submit,
      fields: [
        const FpFieldLabel(text: 'Item'),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          autofillHints: const [],
          decoration: const InputDecoration(
            hintText: 'Rain shell, stove, headlamp…',
            isDense: true,
          ),
          style: FpTypography.bodyStrong,
        ),
        const SizedBox(height: FpSpace.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FpNumberField(
                label: 'Weight each',
                unit: widget.weightSymbol,
                value: _weight,
                decimals: 2,
                max: 100,
                onChanged: (value) => setState(() => _weight = value),
              ),
            ),
            const SizedBox(width: FpSpace.sm),
            Expanded(
              child: FpStepper(
                label: 'Quantity',
                value: _quantity,
                max: 99,
                onChanged: (value) => setState(() => _quantity = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: FpSpace.sm),
        FpChoiceGroup<GearCategory>(
          label: 'Category',
          options: [
            for (final category in GearCategory.values)
              (category, category.label),
          ],
          selected: _category,
          artFor: (category) => category.image,
          onChanged: (value) => setState(() => _category = value),
        ),
      ],
    );
  }
}
