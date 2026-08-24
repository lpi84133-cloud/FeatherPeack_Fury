import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/audio/fp_feedback.dart';
import '../../core/design/fp_colors.dart';
import '../../core/design/fp_images.dart';
import '../../core/design/fp_tokens.dart';
import '../../core/design/fp_typography.dart';
import '../../data/providers.dart';
import '../../domain/calc/food_estimate.dart';
import '../../domain/calc/trip_analysis.dart';
import '../../domain/models/trip.dart';
import '../../shared/widgets/fp_art.dart';
import '../../shared/widgets/fp_card.dart';
import '../../shared/widgets/fp_empty_state.dart';
import '../../shared/widgets/fp_metric.dart';
import '../../shared/widgets/fp_section_header.dart';
import '../trip/create_trip_screen.dart';

const _uuid = Uuid();

/// EggPack: how many meal portions to bring, and why that number.
class EggPackView extends ConsumerWidget {
  const EggPackView({required this.analysis, super.key});

  final TripAnalysis analysis;

  Future<void> _addToPack(BuildContext context, WidgetRef ref) async {
    final food = analysis.food;
    if (food == null) return;
    final trip = analysis.trip;

    final existing = trip.gear.where(
      (item) => item.category == GearCategory.food && item.name == 'EggPack food',
    );
    final gear = [
      ...trip.gear.where((item) => !existing.contains(item)),
      GearItem(
        id: existing.isEmpty ? _uuid.v4() : existing.first.id,
        name: 'EggPack food',
        category: GearCategory.food,
        weightKg: food.approxWeightKg,
      ),
    ];

    await ref.read(tripsProvider.notifier).save(trip.copyWith(gear: gear));
    FpFeedback.instance.success(FpSound.addItem);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${food.totalUnits} units added to the pack as food weight.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final food = analysis.food;
    final format = ref.watch(formatProvider);
    final trip = analysis.trip;

    if (food == null) {
      return Padding(
        padding: const EdgeInsets.all(FpSpace.md),
        child: FpEmptyState(
          art: FpImages.emptyNewTrip,
          title: 'Moving time needed',
          message:
              'The food estimate is built from active hours, group size and '
              'intensity. Add the moving time and it appears here.',
          artSize: 180,
          action: FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CreateTripScreen(existing: trip),
              ),
            ),
            child: const Text('Add moving time'),
          ),
        ),
      );
    }

    final packedFood = trip.gear
        .where((item) => item.category == GearCategory.food)
        .fold<double>(0, (sum, item) => sum + item.totalKg);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        FpSpace.md,
        0,
        FpSpace.md,
        FpSpace.xl,
      ),
      children: [
        FpCard(
          child: Column(
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
                            '${food.totalUnits}',
                            style: FpTypography.heroMetric.copyWith(
                              fontSize: 46,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            food.totalUnits == 1 ? 'Egg Unit' : 'Egg Units',
                            style: FpTypography.title,
                          ),
                        ],
                      ),
                      Text(
                        '${food.unitsPerPerson.toStringAsFixed(1)} per person · '
                        '≈ ${format.weight(food.approxWeightKg)} packed',
                        style: FpTypography.caption,
                      ),
                    ],
                  ),
                  const Spacer(),
                  const FpArt(FpImages.eggLarge, size: 66, height: 80),
                ],
              ),
              const SizedBox(height: FpSpace.sm),
              _EggGrid(count: food.totalUnits),
            ],
          ),
        ),
        const SizedBox(height: FpSpace.md),
        const FpSectionHeader(label: 'How it adds up'),
        const SizedBox(height: FpSpace.xs),
        FpCard(
          child: Column(
            children: [
              FpValueRow(
                label:
                    'Base · 1 unit per person per '
                    '${FoodEstimate.hoursPerUnit.round()} h',
                value: '${food.baseUnits}',
                art: FpImages.eggSingle,
              ),
              FpValueRow(
                label: 'Intensity · ${trip.intensity.label}',
                value: food.intensityUnits == 0
                    ? 'included'
                    : '+${food.intensityUnits}',
                art: FpImages.eggPair,
              ),
              FpValueRow(
                label: food.reserveUnits == 0
                    ? 'Reserve · days under '
                          '${FoodEstimate.reserveThresholdHours.round()} h'
                    : 'Reserve · 1 per person on long days',
                value: food.reserveUnits == 0
                    ? 'none'
                    : '+${food.reserveUnits}',
                art: FpImages.eggGolden,
              ),
              const Divider(height: FpSpace.md),
              FpValueRow(
                label: 'Total',
                value: '${food.totalUnits} units',
                valueColor: FpColors.goldDeep,
              ),
            ],
          ),
        ),
        const SizedBox(height: FpSpace.md),
        const FpSectionHeader(label: 'Inputs'),
        const SizedBox(height: FpSpace.xs),
        FpCard(
          child: Column(
            children: [
              FpValueRow(
                label: 'Moving time',
                value: format.duration(trip.movingMinutes),
                icon: Icons.schedule_rounded,
              ),
              FpValueRow(
                label: 'People',
                value: '${trip.people}',
                icon: Icons.group_rounded,
              ),
              FpValueRow(
                label: 'Intensity',
                value: trip.intensity.label,
                icon: Icons.local_fire_department_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: FpSpace.md),
        FpCard(
          color: FpColors.goldTint,
          border: const BorderSide(color: FpColors.goldSoft),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Carry it over to the pack', style: FpTypography.title),
              const SizedBox(height: FpSpace.xxs),
              Text(
                packedFood == 0
                    ? 'Add roughly ${format.weight(food.approxWeightKg)} of food '
                          'weight to Feather Load so the total load is honest.'
                    : 'Currently ${format.weight(packedFood)} of food is listed '
                          'in the pack against an estimate of '
                          '${format.weight(food.approxWeightKg)}.',
                style: FpTypography.body,
              ),
              const SizedBox(height: FpSpace.sm),
              FilledButton(
                onPressed: () => _addToPack(context, ref),
                style: FilledButton.styleFrom(
                  backgroundColor: FpColors.goldDeep,
                ),
                child: Text(
                  packedFood == 0 ? 'Add food weight' : 'Update food weight',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: FpSpace.md),
        const FpNotice(
          message:
              '1 Egg Unit = one regular meal portion or its equivalent. What '
              'goes into a portion is your call, which keeps the estimate '
              'usable for any kind of food. Packed weight assumes about 150 g '
              'per unit.',
        ),
      ],
    );
  }
}

/// Shows the recommendation as countable objects rather than a bare number.
class _EggGrid extends StatelessWidget {
  const _EggGrid({required this.count});

  final int count;

  static const _maxDrawn = 24;

  @override
  Widget build(BuildContext context) {
    final drawn = math.min(count, _maxDrawn);
    return Wrap(
      spacing: 2,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < drawn; i++)
          const FpArt(FpImages.eggSingle, size: 26, height: 30),
        if (count > _maxDrawn)
          Padding(
            padding: const EdgeInsets.only(left: FpSpace.xxs),
            child: Text(
              '+${count - _maxDrawn}',
              style: FpTypography.bodyStrong.copyWith(
                color: FpColors.goldDeep,
              ),
            ),
          ),
      ],
    );
  }
}
