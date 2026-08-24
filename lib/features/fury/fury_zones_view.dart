import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/fp_colors.dart';
import '../../core/design/fp_images.dart';
import '../../core/design/fp_tokens.dart';
import '../../core/design/fp_typography.dart';
import '../../domain/calc/fury_zones.dart';
import '../../domain/calc/trip_analysis.dart';
import '../../shared/widgets/fp_art.dart';
import '../../shared/widgets/fp_card.dart';
import '../../shared/widgets/fp_empty_state.dart';
import '../../shared/widgets/fp_metric.dart';
import '../../shared/widgets/fp_section_header.dart';
import '../trip/create_trip_screen.dart';

Color _severityColor(FurySeverity severity) => switch (severity) {
  FurySeverity.notice => FpColors.skyDeep,
  FurySeverity.attention => FpColors.hard,
  FurySeverity.high => FpColors.severe,
};

Color _levelColor(FuryLevel level) => switch (level) {
  FuryLevel.clear => FpColors.easy,
  FuryLevel.watch => FpColors.skyDeep,
  FuryLevel.attention => FpColors.hard,
  FuryLevel.high => FpColors.severe,
};

/// Fury Zones: the parameters worth a second look, ordered by how much they
/// matter. Nothing here blocks a plan.
class FuryZonesView extends ConsumerWidget {
  const FuryZonesView({required this.analysis, super.key});

  final TripAnalysis analysis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fury = analysis.fury;

    if (analysis.difficulty.confidence == 0) {
      return Padding(
        padding: const EdgeInsets.all(FpSpace.md),
        child: FpEmptyState(
          art: FpImages.emptyNoRouteData,
          title: 'Nothing to check yet',
          message:
              'Fury Zones read the parameters of the plan. Enter the route '
              'basics and the checks start running.',
          artSize: 180,
          action: FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CreateTripScreen(existing: analysis.trip),
              ),
            ),
            child: const Text('Add parameters'),
          ),
        ),
      );
    }

    final color = _levelColor(fury.level);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        FpSpace.md,
        0,
        FpSpace.md,
        FpSpace.xl,
      ),
      children: [
        FpCard(
          color: color.withValues(alpha: 0.07),
          border: BorderSide(color: color.withValues(alpha: 0.3)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FpArt(
                fury.level == FuryLevel.clear
                    ? FpImages.chickenResting
                    : FpImages.furySteepSign,
                size: 54,
                height: 66,
              ),
              const SizedBox(width: FpSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fury.level.label,
                      style: FpTypography.title.copyWith(color: color),
                    ),
                    const SizedBox(height: 2),
                    Text(fury.level.summary, style: FpTypography.body),
                    if (fury.findings.isNotEmpty) ...[
                      const SizedBox(height: FpSpace.xs),
                      Row(
                        children: [
                          FpTag(
                            label:
                                '${fury.findings.length} '
                                '${fury.findings.length == 1 ? 'item' : 'items'}',
                            color: color,
                          ),
                          if (fury.highCount > 0) ...[
                            const SizedBox(width: FpSpace.xxs),
                            FpTag(
                              label: '${fury.highCount} high',
                              color: FpColors.severe,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (fury.findings.isEmpty) ...[
          const SizedBox(height: FpSpace.lg),
          FpCard(
            child: Row(
              children: [
                const FpArt(FpImages.markerFlag, size: 44, height: 56),
                const SizedBox(width: FpSpace.sm),
                Expanded(
                  child: Text(
                    'Nothing in this plan crosses a threshold. As you add more '
                    'detail the checks re-run automatically.',
                    style: FpTypography.body,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: FpSpace.md),
          const FpSectionHeader(label: 'Worth attention'),
          const SizedBox(height: FpSpace.xs),
          for (final finding in fury.findings)
            Padding(
              padding: const EdgeInsets.only(bottom: FpSpace.xs),
              child: _FindingCard(finding: finding),
            ),
        ],
        const SizedBox(height: FpSpace.md),
        const FpNotice(
          message:
              'These are informational flags based on the numbers you entered. '
              'They highlight what to prepare for — they are not a safety '
              'clearance or a recommendation to turn back.',
          icon: Icons.shield_outlined,
        ),
      ],
    );
  }
}

class _FindingCard extends StatelessWidget {
  const _FindingCard({required this.finding});

  final FuryFinding finding;

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(finding.severity);

    return FpCard(
      padding: const EdgeInsets.all(FpSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 44,
            margin: const EdgeInsets.only(right: FpSpace.xs, top: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: FpRadius.pillAll,
            ),
          ),
          FpArt(finding.image, size: 40, height: 48),
          const SizedBox(width: FpSpace.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(finding.title, style: FpTypography.title),
                    ),
                    FpTag(label: finding.severity.label, color: color),
                  ],
                ),
                const SizedBox(height: 2),
                Text(finding.detail, style: FpTypography.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
