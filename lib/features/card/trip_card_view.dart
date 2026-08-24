import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/fp_feedback.dart';
import '../../core/design/fp_colors.dart';
import '../../core/design/fp_images.dart';
import '../../core/design/fp_tokens.dart';
import '../../core/design/fp_typography.dart';
import '../../core/utils/fp_format.dart';
import '../../data/providers.dart';
import '../../domain/calc/trip_analysis.dart';
import '../../shared/widgets/fp_art.dart';
import '../../shared/widgets/fp_card.dart';
import '../../shared/widgets/fp_metric.dart';
import '../../shared/widgets/fp_section_header.dart';
import '../peak/route_analyzer_view.dart';
import '../trip/workspace_section.dart';

/// The summary the user actually takes with them: every figure that matters on
/// one screen, available with no connection.
class TripCardView extends ConsumerWidget {
  const TripCardView({
    required this.analysis,
    required this.onSectionRequested,
    super.key,
  });

  final TripAnalysis analysis;
  final ValueChanged<WorkspaceSection> onSectionRequested;

  static WorkspaceSection sectionFor(MissingInput input) => switch (input) {
    MissingInput.distance ||
    MissingInput.duration ||
    MissingInput.terrain => WorkspaceSection.route,
    MissingInput.elevation => WorkspaceSection.peak,
    MissingInput.load || MissingInput.water => WorkspaceSection.load,
    MissingInput.expenses => WorkspaceSection.budget,
  };

  String _plainText(FpFormat format) {
    final trip = analysis.trip;
    final lines = <String>[
      trip.name,
      if (trip.plannedDate != null) format.date(trip.plannedDate),
      '',
      'Difficulty: ${analysis.difficulty.score}/100 '
          '(${analysis.difficulty.tier.label})',
      'Distance: ${format.distance(trip.distanceKm)}',
      'Elevation gain: ${format.elevation(trip.elevationGainM)}',
      'Moving time: ${format.duration(trip.movingMinutes)}',
      'Terrain: ${trip.terrain?.label ?? '—'}',
      'People: ${trip.people}',
      'Water: ${format.volume(trip.waterLitres)}',
      'Load: ${format.weight(analysis.load.totalKg)}',
      'Food: ${analysis.food == null ? '—' : '${analysis.food!.totalUnits} Egg Units'}',
      'Budget: ${analysis.budget.isEmpty ? '—' : format.money(analysis.budget.total)}',
    ];
    if (analysis.fury.findings.isNotEmpty) {
      lines
        ..add('')
        ..add('Fury Zones — ${analysis.fury.level.label}:');
      for (final finding in analysis.fury.findings) {
        lines.add('· ${finding.title}: ${finding.detail}');
      }
    }
    if (trip.notes.isNotEmpty) {
      lines
        ..add('')
        ..add('Notes: ${trip.notes}');
    }
    return lines.join('\n');
  }

  Future<void> _copy(BuildContext context, FpFormat format) async {
    await Clipboard.setData(ClipboardData(text: _plainText(format)));
    FpFeedback.instance.success(FpSound.successfulAction);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Trip summary copied as plain text.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final format = ref.watch(formatProvider);
    final trip = analysis.trip;
    final difficulty = analysis.difficulty;
    final tierColor = difficultyColor(difficulty.tier);
    final food = analysis.food;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        FpSpace.md,
        0,
        FpSpace.md,
        FpSpace.xl,
      ),
      children: [
        FpCard(
          padding: EdgeInsets.zero,
          borderRadius: FpRadius.heroAll,
          shadow: FpShadow.lifted,
          child: ClipRRect(
            borderRadius: FpRadius.heroAll,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(FpSpace.md),
                  color: FpColors.forestDeep,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'OFFLINE TRIP CARD',
                              style: FpTypography.overline.copyWith(
                                color: FpColors.goldSoft,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              trip.name,
                              style: FpTypography.titleLarge.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              trip.plannedDate == null
                                  ? 'No date set'
                                  : format.date(trip.plannedDate),
                              style: FpTypography.caption.copyWith(
                                color: const Color(0xCCFFFFFF),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const FpArt(
                        FpImages.markerSummitPost,
                        size: 46,
                        height: 58,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(FpSpace.md),
                  color: FpColors.surface,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DIFFICULTY',
                                  style: FpTypography.overline,
                                ),
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '${difficulty.score}',
                                      style: FpTypography.heroMetric.copyWith(
                                        fontSize: 44,
                                        color: tierColor,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '/ 100',
                                      style: FpTypography.label,
                                    ),
                                  ],
                                ),
                                FpTag(
                                  label: difficulty.tier.label,
                                  color: tierColor,
                                  filled: true,
                                ),
                              ],
                            ),
                          ),
                          FpArt(
                            difficultyArt(difficulty.tier),
                            size: 84,
                            height: 84,
                          ),
                        ],
                      ),
                      const Divider(height: FpSpace.lg),
                      GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: FpSpace.xs,
                        mainAxisSpacing: FpSpace.xs,
                        childAspectRatio: 1.35,
                        children: [
                          _CardCell(
                            label: 'Distance',
                            value: format.distance(trip.distanceKm),
                          ),
                          _CardCell(
                            label: 'Elevation',
                            value: format.elevation(trip.elevationGainM),
                          ),
                          _CardCell(
                            label: 'Time',
                            value: format.duration(trip.movingMinutes),
                          ),
                          _CardCell(
                            label: 'Load',
                            value: analysis.load.totalKg == 0
                                ? '—'
                                : format.weight(analysis.load.totalKg),
                          ),
                          _CardCell(
                            label: 'Water',
                            value: format.volume(trip.waterLitres),
                          ),
                          _CardCell(
                            label: 'Food',
                            value: food == null ? '—' : '${food.totalUnits} eggs',
                          ),
                          _CardCell(
                            label: 'Budget',
                            value: analysis.budget.isEmpty
                                ? '—'
                                : format.money(analysis.budget.total),
                          ),
                          _CardCell(label: 'People', value: '${trip.people}'),
                          _CardCell(
                            label: 'Flags',
                            value: '${analysis.fury.findings.length}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (analysis.fury.findings.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(FpSpace.md),
                    color: FpColors.surfaceAlt,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FURY ZONES · ${analysis.fury.level.label.toUpperCase()}',
                          style: FpTypography.overline,
                        ),
                        const SizedBox(height: FpSpace.xs),
                        for (final finding in analysis.fury.findings.take(4))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              children: [
                                const Text('· '),
                                Expanded(
                                  child: Text(
                                    finding.title,
                                    style: FpTypography.body,
                                  ),
                                ),
                                Text(
                                  finding.severity.label,
                                  style: FpTypography.caption,
                                ),
                              ],
                            ),
                          ),
                        if (analysis.fury.findings.length > 4)
                          Text(
                            '+${analysis.fury.findings.length - 4} more in Fury Zones',
                            style: FpTypography.caption,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (trip.notes.isNotEmpty) ...[
          const SizedBox(height: FpSpace.md),
          const FpSectionHeader(label: 'Notes'),
          const SizedBox(height: FpSpace.xs),
          FpCard(child: Text(trip.notes, style: FpTypography.body)),
        ],
        const SizedBox(height: FpSpace.md),
        if (analysis.missing.isNotEmpty) ...[
          const FpSectionHeader(label: 'Still missing'),
          const SizedBox(height: FpSpace.xs),
          FpCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The card shows what you entered. These parameters would make '
                  'it complete:',
                  style: FpTypography.body,
                ),
                const SizedBox(height: FpSpace.xs),
                for (final input in analysis.missing)
                  InkWell(
                    onTap: () {
                      FpFeedback.instance.tap();
                      onSectionRequested(sectionFor(input));
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.add_circle_outline_rounded,
                            size: 18,
                            color: FpColors.forest,
                          ),
                          const SizedBox(width: FpSpace.xs),
                          Expanded(
                            child: Text(
                              '${input.label} — affects ${input.affects}',
                              style: FpTypography.body,
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: FpColors.graphiteSoft,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: FpSpace.md),
        ],
        OutlinedButton.icon(
          onPressed: () => _copy(context, format),
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy summary as text'),
        ),
        const SizedBox(height: FpSpace.sm),
        const FpNotice(
          message:
              'This card is stored on your device and stays readable with no '
              'connection. Copy it as text to paste into a message before you '
              'leave.',
          icon: Icons.wifi_off_rounded,
        ),
      ],
    );
  }
}

class _CardCell extends StatelessWidget {
  const _CardCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(FpSpace.xs),
      decoration: BoxDecoration(
        color: FpColors.canvas,
        borderRadius: FpRadius.tileAll,
        border: Border.fromBorderSide(FpBorders.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: FpTypography.overline.copyWith(fontSize: 9),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: FpTypography.metricSmall.copyWith(fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
