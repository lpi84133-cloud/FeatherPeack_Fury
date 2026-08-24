import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/fp_colors.dart';
import '../../core/design/fp_images.dart';
import '../../core/design/fp_tokens.dart';
import '../../core/design/fp_typography.dart';
import '../../data/providers.dart';
import '../../domain/calc/peak_profile.dart';
import '../../domain/calc/trip_analysis.dart';
import '../../shared/widgets/fp_card.dart';
import '../../shared/widgets/fp_empty_state.dart';
import '../../shared/widgets/fp_metric.dart';
import '../../shared/widgets/fp_section_header.dart';
import '../trip/create_trip_screen.dart';

Color _segmentColor(SegmentKind kind) => switch (kind) {
  SegmentKind.uphill => FpColors.forest,
  SegmentKind.downhill => FpColors.skyDeep,
  SegmentKind.flat => FpColors.forestSoft,
  SegmentKind.hard => FpColors.hard,
};

/// Turns the route numbers into a shape the eye can read: where the climb sits,
/// how long the descent runs and which stretch is the hardest.
class PeakProfileView extends ConsumerWidget {
  const PeakProfileView({required this.analysis, super.key});

  final TripAnalysis analysis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = analysis.profile;
    final format = ref.watch(formatProvider);
    final trip = analysis.trip;

    if (profile == null) {
      return Padding(
        padding: const EdgeInsets.all(FpSpace.md),
        child: FpEmptyState(
          art: FpImages.emptyNoRouteData,
          title: 'Nothing to draw yet',
          message:
              'The profile needs a distance to lay the route out along, and an '
              'elevation gain to give it shape.',
          artSize: 180,
          action: FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CreateTripScreen(existing: trip),
              ),
            ),
            child: const Text('Add distance and elevation'),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        FpSpace.md,
        0,
        FpSpace.md,
        FpSpace.xl,
      ),
      children: [
        FpCard(
          padding: const EdgeInsets.fromLTRB(
            FpSpace.xs,
            FpSpace.md,
            FpSpace.sm,
            FpSpace.xs,
          ),
          child: Column(
            children: [
              SizedBox(height: 210, child: _ProfileChart(profile: profile)),
              const SizedBox(height: FpSpace.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final kind in SegmentKind.values) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _segmentColor(kind),
                        borderRadius: FpRadius.pillAll,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(kind.label, style: FpTypography.caption),
                    if (kind != SegmentKind.values.last)
                      const SizedBox(width: FpSpace.sm),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: FpSpace.md),
        const FpSectionHeader(label: 'Sections'),
        const SizedBox(height: FpSpace.xs),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: FpSpace.xs,
          mainAxisSpacing: FpSpace.xs,
          childAspectRatio: 1.42,
          children: [
            FpMetricTile(
              label: 'Uphill',
              value: format.distance(profile.uphillKm),
              icon: Icons.trending_up_rounded,
              accent: _segmentColor(SegmentKind.uphill),
            ),
            FpMetricTile(
              label: 'Downhill',
              value: format.distance(profile.downhillKm),
              icon: Icons.trending_down_rounded,
              accent: _segmentColor(SegmentKind.downhill),
            ),
            FpMetricTile(
              label: 'Flat',
              value: format.distance(profile.flatKm),
              icon: Icons.trending_flat_rounded,
              accent: _segmentColor(SegmentKind.flat),
            ),
            FpMetricTile(
              label: 'Hard',
              value: format.distance(profile.hardKm),
              art: FpImages.furySteepSign,
              accent: _segmentColor(SegmentKind.hard),
              footnote: profile.hardKm > 0
                  ? 'Steepest ${profile.steepestGradePercent.toStringAsFixed(0)}%'
                  : 'No steep stretch',
            ),
          ],
        ),
        const SizedBox(height: FpSpace.md),
        FpCard(
          child: Column(
            children: [
              FpValueRow(
                label: 'Highest point above the start',
                value: format.elevation(profile.peakElevationM),
                art: FpImages.peakSnow,
              ),
              FpValueRow(
                label: 'Average climb rate',
                value: trip.distanceKm == null || trip.distanceKm == 0
                    ? '—'
                    : '${format.elevation((trip.elevationGainM ?? 0) / trip.distanceKm!, withUnit: false)} '
                          '${format.elevationSymbol} / ${format.distanceSymbol}',
                icon: Icons.speed_rounded,
              ),
              FpValueRow(
                label: 'Terrain',
                value: trip.terrain?.label ?? 'Not set',
                art: trip.terrain?.image ?? FpImages.terrainGrass,
              ),
            ],
          ),
        ),
        const SizedBox(height: FpSpace.md),
        FpNotice(
          message: profile.isEstimated
              ? 'No elevation gain entered, so the profile is drawn flat. Add '
                    'the climb to see the real shape of the route.'
              : 'A conditional profile built from your distance, elevation and '
                    'terrain. It shows where the effort concentrates — it is not '
                    'surveyed map data.',
          icon: Icons.info_outline_rounded,
        ),
      ],
    );
  }
}

class _ProfileChart extends ConsumerWidget {
  const _ProfileChart({required this.profile});

  final PeakProfileResult profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final format = ref.watch(formatProvider);
    final maxElevation = profile.points
        .map((p) => p.elevationM)
        .fold<double>(1, (a, b) => a > b ? a : b);
    final maxDistance = profile.points.last.distanceKm;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: format.kmToDistance(maxDistance),
        minY: 0,
        maxY: format.metresToElevation(maxElevation * 1.25),
        lineTouchData: const LineTouchData(enabled: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: format.metresToElevation(maxElevation) / 3,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: FpColors.outline, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: format.metresToElevation(maxElevation) / 3,
              getTitlesWidget: (value, meta) => Text(
                value.round().toString(),
                style: FpTypography.caption.copyWith(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: format.kmToDistance(maxDistance) / 4,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  value.toStringAsFixed(value >= 10 ? 0 : 1),
                  style: FpTypography.caption.copyWith(fontSize: 10),
                ),
              ),
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (final point in profile.points)
                FlSpot(
                  format.kmToDistance(point.distanceKm),
                  format.metresToElevation(point.elevationM),
                ),
            ],
            isCurved: true,
            curveSmoothness: 0.22,
            barWidth: 2.5,
            color: FpColors.forest,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x5524501C), Color(0x0824501C)],
              ),
            ),
          ),
        ],
      ),
      duration: FpMotion.slow,
      curve: FpMotion.curve,
    );
  }
}
