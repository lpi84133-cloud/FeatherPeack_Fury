import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/fp_colors.dart';
import '../../core/design/fp_images.dart';
import '../../core/design/fp_tokens.dart';
import '../../core/design/fp_typography.dart';
import '../../data/providers.dart';
import '../../domain/calc/difficulty.dart';
import '../../domain/calc/trip_analysis.dart';
import '../../shared/widgets/fp_card.dart';
import '../../shared/widgets/fp_empty_state.dart';
import '../../shared/widgets/fp_gauge.dart';
import '../../shared/widgets/fp_metric.dart';
import '../../shared/widgets/fp_section_header.dart';
import '../trip/create_trip_screen.dart';

Color difficultyColor(DifficultyTier tier) => switch (tier) {
  DifficultyTier.easy => FpColors.easy,
  DifficultyTier.moderate => FpColors.moderate,
  DifficultyTier.hard => FpColors.hard,
  DifficultyTier.veryHard => FpColors.severe,
};

String difficultyArt(DifficultyTier tier) => switch (tier) {
  DifficultyTier.easy => FpImages.terrainGrass,
  DifficultyTier.moderate => FpImages.peakGreen,
  DifficultyTier.hard => FpImages.peakRock,
  DifficultyTier.veryHard => FpImages.peakSnow,
};

/// The weighted difficulty result, with every factor's contribution shown so the
/// score is explainable rather than a black box.
class RouteAnalyzerView extends ConsumerWidget {
  const RouteAnalyzerView({required this.analysis, super.key});

  final TripAnalysis analysis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final difficulty = analysis.difficulty;
    final format = ref.watch(formatProvider);
    final trip = analysis.trip;

    if (difficulty.confidence == 0) {
      return Padding(
        padding: const EdgeInsets.all(FpSpace.md),
        child: FpEmptyState(
          art: FpImages.emptyNoRouteData,
          title: 'No route data yet',
          message:
              'Add at least a distance and a moving time and the difficulty '
              'score appears here immediately.',
          artSize: 180,
          action: FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CreateTripScreen(existing: trip),
              ),
            ),
            child: const Text('Add route parameters'),
          ),
        ),
      );
    }

    final color = difficultyColor(difficulty.tier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        FpSpace.md,
        0,
        FpSpace.md,
        FpSpace.xl,
      ),
      children: [
        FpCard(
          padding: const EdgeInsets.all(FpSpace.md),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  FpArcGauge(
                    value: difficulty.score / 100,
                    label: '${difficulty.score}',
                    caption: 'of 100',
                    color: color,
                    art: difficultyArt(difficulty.tier),
                    size: 138,
                  ),
                  const SizedBox(width: FpSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DIFFICULTY', style: FpTypography.overline),
                        const SizedBox(height: 2),
                        Text(
                          difficulty.tier.label,
                          style: FpTypography.title.copyWith(color: color),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: FpSpace.xs),
                        FpTag(
                          label:
                              'Band ${difficulty.tier.from}–${difficulty.tier.to}',
                          color: color,
                        ),
                        const SizedBox(height: FpSpace.xs),
                        Text(
                          difficulty.isComplete
                              ? 'All five factors evaluated.'
                              : '${format.percent(difficulty.confidence)} of the '
                                    'model evaluated.',
                          style: FpTypography.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!difficulty.isComplete) ...[
                const SizedBox(height: FpSpace.sm),
                FpNotice(
                  message:
                      'Missing '
                      '${difficulty.missingFactors.map((f) => f.label.toLowerCase()).join(', ')}. '
                      'The score is calculated from the factors you did '
                      'provide, so it may shift once the rest is filled in.',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: FpSpace.md),
        const FpSectionHeader(label: 'Factor contribution'),
        const SizedBox(height: FpSpace.xs),
        FpCard(
          child: Column(
            children: [
              for (final factor in difficulty.factors) ...[
                _FactorRow(score: factor, tint: color),
                if (factor != difficulty.factors.last)
                  const Divider(height: FpSpace.md),
              ],
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
                label: 'Distance',
                value: format.distance(trip.distanceKm),
                art: FpImages.markerAscentSign,
              ),
              FpValueRow(
                label: 'Elevation gain',
                value: format.elevation(trip.elevationGainM),
                art: FpImages.peakGreen,
              ),
              FpValueRow(
                label: 'Moving time',
                value: format.duration(trip.movingMinutes),
                icon: Icons.schedule_rounded,
              ),
              FpValueRow(
                label: 'Terrain',
                value: trip.terrain?.label ?? '—',
                art: trip.terrain?.image ?? FpImages.terrainGrass,
              ),
              FpValueRow(
                label: 'Carried load',
                value: trip.hasLoadData
                    ? format.weight(trip.totalLoadKg)
                    : '—',
                art: FpImages.featherGreen,
              ),
              FpValueRow(
                label: 'Group',
                value: '${trip.people}',
                icon: Icons.group_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: FpSpace.md),
        const FpNotice(
          message:
              'This score is a preparation aid based on the numbers you entered. '
              'It is not a medical, rescue or professional route assessment.',
          icon: Icons.shield_outlined,
        ),
      ],
    );
  }
}

class _FactorRow extends StatelessWidget {
  const _FactorRow({required this.score, required this.tint});

  final FactorScore score;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                score.factor.label,
                style: FpTypography.bodyStrong.copyWith(
                  color: score.known
                      ? FpColors.graphite
                      : FpColors.graphiteSoft,
                ),
              ),
            ),
            Text(
              score.known ? '${score.points} / ${score.maxPoints}' : 'Not set',
              style: FpTypography.label.copyWith(
                color: score.known ? FpColors.graphiteMid : FpColors.graphiteSoft,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        FpShareBar(
          share: score.known ? score.ratio : 0,
          color: score.known ? tint : FpColors.outline,
          height: 7,
        ),
      ],
    );
  }
}
