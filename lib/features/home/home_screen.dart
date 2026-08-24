import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/fp_feedback.dart';
import '../../core/design/fp_colors.dart';
import '../../core/design/fp_images.dart';
import '../../core/design/fp_tokens.dart';
import '../../core/design/fp_typography.dart';
import '../../data/providers.dart';
import '../../domain/calc/trip_analysis.dart';
import '../../domain/models/trip.dart';
import '../../shared/widgets/fp_art.dart';
import '../../shared/widgets/fp_avatar.dart';
import '../../shared/widgets/fp_card.dart';
import '../../shared/widgets/fp_empty_state.dart';
import '../../shared/widgets/fp_metric.dart';
import '../../shared/widgets/fp_screen.dart';
import '../../shared/widgets/fp_section_header.dart';
import '../archive/archive_screen.dart';
import '../peak/route_analyzer_view.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';
import '../trip/create_trip_screen.dart';
import '../trip/trip_workspace_screen.dart';
import '../trip/workspace_section.dart';

/// Basecamp: the trip you are working on, the four parts of the plan, and the
/// way back into anything you saved earlier.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static Future<void> openWorkspace(
    BuildContext context,
    WidgetRef ref,
    Trip trip, {
    WorkspaceSection section = WorkspaceSection.route,
  }) async {
    FpFeedback.instance.play(FpSound.screenOpen);
    await ref.read(currentTripIdProvider.notifier).select(trip.id);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            TripWorkspaceScreen(tripId: trip.id, initialSection: section),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripsProvider);
    final current = ref.watch(currentTripProvider);
    final profile = ref.watch(profileProvider);
    final stats = ref.watch(archiveStatsProvider);

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 300,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    FpImages.mountainBackdrop,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x33F7F3EA), Color(0xFFF7F3EA)],
                        stops: [0.35, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    FpSpace.md,
                    FpSpace.xs,
                    FpSpace.md,
                    FpSpace.xs,
                  ),
                  child: Row(
                    children: [
                      FpAvatar(
                        size: 46,
                        onTap: () {
                          FpFeedback.instance.play(FpSound.screenOpen);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ProfileScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: FpSpace.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BASECAMP', style: FpTypography.overline),
                            Text(
                              profile.hasName
                                  ? 'Ready when you are, ${profile.name.split(' ').first}'
                                  : 'Ready when you are',
                              style: FpTypography.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      FpRoundButton(
                        icon: Icons.settings_outlined,
                        tooltip: 'Settings',
                        onPressed: () {
                          FpFeedback.instance.play(FpSound.screenOpen);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      FpSpace.md,
                      FpSpace.xs,
                      FpSpace.md,
                      FpSpace.xl,
                    ),
                    children: [
                      if (current == null)
                        _NoTripHero(hasArchive: trips.isNotEmpty)
                      else
                        _CurrentTripHero(
                          analysis: ref.watch(analysisProvider(current)),
                        ),
                      const SizedBox(height: FpSpace.md),
                      FilledButton.icon(
                        onPressed: () {
                          FpFeedback.instance.play(FpSound.screenOpen);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CreateTripScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Plan a new trip'),
                      ),
                      if (current != null) ...[
                        const SizedBox(height: FpSpace.lg),
                        const FpSectionHeader(label: 'The four parts'),
                        const SizedBox(height: FpSpace.xs),
                        _SystemTiles(
                          analysis: ref.watch(analysisProvider(current)),
                        ),
                      ],
                      const SizedBox(height: FpSpace.lg),
                      FpSectionHeader(
                        label: 'Trip archive · ${trips.length}',
                        trailing: trips.isEmpty
                            ? null
                            : TextButton(
                                onPressed: () {
                                  FpFeedback.instance.play(FpSound.screenOpen);
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const ArchiveScreen(),
                                    ),
                                  );
                                },
                                child: const Text('See all'),
                              ),
                      ),
                      const SizedBox(height: FpSpace.xs),
                      if (trips.isEmpty)
                        FpCard(
                          child: Row(
                            children: [
                              const FpArt(
                                FpImages.emptyNoSavedTrips,
                                size: 66,
                                height: 82,
                              ),
                              const SizedBox(width: FpSpace.sm),
                              Expanded(
                                child: Text(
                                  'Saved trips land here. Each one keeps its '
                                  'own gear list, food estimate and budget so '
                                  'you can reuse it as a template.',
                                  style: FpTypography.body,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        for (final trip in trips.take(3))
                          Padding(
                            padding: const EdgeInsets.only(bottom: FpSpace.xs),
                            child: _ArchiveRow(trip: trip),
                          ),
                      if (!stats.isEmpty) ...[
                        const SizedBox(height: FpSpace.lg),
                        const FpSectionHeader(label: 'Your planning so far'),
                        const SizedBox(height: FpSpace.xs),
                        const _StatsRow(),
                      ],
                      const SizedBox(height: FpSpace.lg),
                      Center(
                        child: Column(
                          children: [
                            const FpArt(
                              FpImages.chickenResting,
                              size: 54,
                              height: 54,
                            ),
                            const SizedBox(height: FpSpace.xxs),
                            Text(
                              'Everything here is calculated and stored on this '
                              'device. No account, no connection required.',
                              style: FpTypography.caption,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentTripHero extends ConsumerWidget {
  const _CurrentTripHero({required this.analysis});

  final TripAnalysis analysis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final format = ref.watch(formatProvider);
    final trip = analysis.trip;
    final difficulty = analysis.difficulty;
    final color = difficultyColor(difficulty.tier);

    return FpCard(
      borderRadius: FpRadius.heroAll,
      shadow: FpShadow.lifted,
      padding: const EdgeInsets.all(FpSpace.md),
      onTap: () => HomeScreen.openWorkspace(context, ref, trip),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CURRENT TRIP', style: FpTypography.overline),
                    const SizedBox(height: 2),
                    Text(
                      trip.name,
                      style: FpTypography.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: FpSpace.xxs),
                    Row(
                      children: [
                        FpTag(
                          label: difficulty.confidence == 0
                              ? 'Not scored yet'
                              : '${difficulty.tier.label} · ${difficulty.score}/100',
                          color: color,
                        ),
                        const SizedBox(width: FpSpace.xxs),
                        if (trip.plannedDate != null)
                          Text(
                            format.date(trip.plannedDate),
                            style: FpTypography.caption,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: FpSpace.xs),
              FpArt(difficultyArt(difficulty.tier), size: 74, height: 74),
            ],
          ),
          const Divider(height: FpSpace.lg),
          Row(
            children: [
              _HeroFigure(
                label: 'Distance',
                value: format.distance(trip.distanceKm),
              ),
              _HeroFigure(
                label: 'Climb',
                value: format.elevation(trip.elevationGainM),
              ),
              _HeroFigure(
                label: 'Time',
                value: format.duration(trip.movingMinutes),
              ),
            ],
          ),
          const SizedBox(height: FpSpace.sm),
          Row(
            children: [
              Expanded(
                child: FpShareBar(
                  share: analysis.completeness,
                  color: FpColors.forest,
                  height: 6,
                ),
              ),
              const SizedBox(width: FpSpace.xs),
              Text(
                '${format.percent(analysis.completeness)} planned',
                style: FpTypography.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroFigure extends StatelessWidget {
  const _HeroFigure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: FpTypography.overline),
          Text(value, style: FpTypography.metricSmall.copyWith(fontSize: 18)),
        ],
      ),
    );
  }
}

class _NoTripHero extends ConsumerWidget {
  const _NoTripHero({required this.hasArchive});

  final bool hasArchive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FpCard(
      borderRadius: FpRadius.heroAll,
      shadow: FpShadow.lifted,
      padding: const EdgeInsets.all(FpSpace.lg),
      child: FpEmptyState(
        art: FpImages.emptyNewTrip,
        title: hasArchive ? 'No trip open' : 'Plan your first trip',
        message: hasArchive
            ? 'Open one from the archive below, or start a new plan from '
                  'scratch.'
            : 'Enter what you know about the route — distance, climb, time — '
                  'and Featherpeak Fury works out the difficulty, the load, the '
                  'food and the budget locally.',
        artSize: 160,
      ),
    );
  }
}

class _SystemTiles extends ConsumerWidget {
  const _SystemTiles({required this.analysis});

  final TripAnalysis analysis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final format = ref.watch(formatProvider);
    final food = analysis.food;

    final tiles = <(WorkspaceSection, String, String, String)>[
      (
        WorkspaceSection.peak,
        'Peak',
        analysis.profile == null
            ? 'No profile'
            : '${format.distance(analysis.profile!.uphillKm)} up',
        FpImages.peakGreen,
      ),
      (
        WorkspaceSection.load,
        'Feather',
        analysis.load.totalKg == 0
            ? 'Not listed'
            : format.weight(analysis.load.totalKg),
        FpImages.featherGreen,
      ),
      (
        WorkspaceSection.food,
        'Egg',
        food == null ? 'No estimate' : '${food.totalUnits} units',
        FpImages.eggSingle,
      ),
      (
        WorkspaceSection.budget,
        'Coin',
        analysis.budget.isEmpty
            ? 'No expenses'
            : format.money(analysis.budget.total),
        FpImages.coinStack,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: FpSpace.xs,
      mainAxisSpacing: FpSpace.xs,
      childAspectRatio: 2.1,
      children: [
        for (final (section, title, value, art) in tiles)
          FpCard(
            onTap: () => HomeScreen.openWorkspace(
              context,
              ref,
              analysis.trip,
              section: section,
            ),
            padding: const EdgeInsets.all(FpSpace.sm),
            child: Row(
              children: [
                FpArt(art, size: 34, height: 40),
                const SizedBox(width: FpSpace.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(title.toUpperCase(), style: FpTypography.overline),
                      Text(
                        value,
                        style: FpTypography.bodyStrong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ArchiveRow extends ConsumerWidget {
  const _ArchiveRow({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = ref.watch(analysisProvider(trip));
    final format = ref.watch(formatProvider);
    final color = difficultyColor(analysis.difficulty.tier);

    return FpCard(
      padding: const EdgeInsets.all(FpSpace.sm),
      onTap: () => HomeScreen.openWorkspace(context, ref, trip),
      child: Row(
        children: [
          FpArt(difficultyArt(analysis.difficulty.tier), size: 40, height: 44),
          const SizedBox(width: FpSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.name,
                  style: FpTypography.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${format.distance(trip.distanceKm)} · '
                  '${format.elevation(trip.elevationGainM)} · '
                  '${format.duration(trip.movingMinutes)}',
                  style: FpTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: FpSpace.xs),
          if (analysis.difficulty.confidence > 0)
            FpTag(label: '${analysis.difficulty.score}', color: color),
        ],
      ),
    );
  }
}

class _StatsRow extends ConsumerWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(archiveStatsProvider);
    final format = ref.watch(formatProvider);

    return Row(
      children: [
        Expanded(
          child: FpMetricTile(
            label: 'Trips',
            value: '${stats.tripCount}',
            icon: Icons.map_outlined,
          ),
        ),
        const SizedBox(width: FpSpace.xs),
        Expanded(
          child: FpMetricTile(
            label: 'Distance',
            value: format.distance(stats.totalDistanceKm, decimals: 0),
            icon: Icons.straighten_rounded,
          ),
        ),
        const SizedBox(width: FpSpace.xs),
        Expanded(
          child: FpMetricTile(
            label: 'Climb',
            value: format.elevation(stats.totalElevationM),
            icon: Icons.terrain_rounded,
          ),
        ),
      ],
    );
  }
}
