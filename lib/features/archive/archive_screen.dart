import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../core/audio/fp_feedback.dart';
import '../../core/design/fp_colors.dart';
import '../../core/design/fp_images.dart';
import '../../core/design/fp_tokens.dart';
import '../../core/design/fp_typography.dart';
import '../../data/providers.dart';
import '../../domain/calc/trip_analysis.dart';
import '../../domain/models/trip.dart';
import '../../shared/widgets/fp_art.dart';
import '../../shared/widgets/fp_card.dart';
import '../../shared/widgets/fp_empty_state.dart';
import '../../shared/widgets/fp_metric.dart';
import '../../shared/widgets/fp_screen.dart';
import '../home/home_screen.dart';
import '../peak/route_analyzer_view.dart';
import '../trip/create_trip_screen.dart';

enum _Sort {
  recent('Recently updated'),
  date('Planned date'),
  name('Name'),
  difficulty('Difficulty');

  const _Sort(this.label);

  final String label;
}

/// Every saved plan, searchable and reusable. Trips are templates as much as
/// records: duplicate one and adjust it rather than starting over.
class ArchiveScreen extends ConsumerStatefulWidget {
  const ArchiveScreen({super.key});

  @override
  ConsumerState<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends ConsumerState<ArchiveScreen> {
  final _search = TextEditingController();
  _Sort _sort = _Sort.recent;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Trip> _visible(List<Trip> trips) {
    final query = _search.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? [...trips]
        : trips
              .where(
                (trip) =>
                    trip.name.toLowerCase().contains(query) ||
                    trip.notes.toLowerCase().contains(query),
              )
              .toList();

    switch (_sort) {
      case _Sort.recent:
        filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      case _Sort.name:
        filtered.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case _Sort.date:
        filtered.sort((a, b) {
          final left = a.plannedDate;
          final right = b.plannedDate;
          if (left == null && right == null) return 0;
          if (left == null) return 1;
          if (right == null) return -1;
          return left.compareTo(right);
        });
      case _Sort.difficulty:
        final profile = ref.read(profileProvider);
        final scores = {
          for (final trip in filtered)
            trip.id: TripAnalysis.of(trip, profile).difficulty.score,
        };
        filtered.sort((a, b) => scores[b.id]!.compareTo(scores[a.id]!));
    }
    return filtered;
  }

  Future<void> _delete(Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this trip?'),
        content: Text('"${trip.name}" will be removed from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: FpColors.severe),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    FpFeedback.instance.play(FpSound.removeItem);
    await ref.read(tripsProvider.notifier).delete(trip.id);
  }

  Future<void> _duplicate(Trip trip) async {
    await ref.read(tripsProvider.notifier).duplicate(trip);
    FpFeedback.instance.success(FpSound.saveTrip);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${trip.name}" duplicated as a template.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(tripsProvider);
    final visible = _visible(trips);

    return FpScreen(
      title: 'Trip archive',
      subtitle: '${trips.length} saved on this device',
      actions: [
        PopupMenuButton<_Sort>(
          tooltip: 'Sort',
          icon: const Icon(Icons.sort_rounded),
          initialValue: _sort,
          onSelected: (value) => setState(() => _sort = value),
          itemBuilder: (context) => [
            for (final sort in _Sort.values)
              PopupMenuItem(value: sort, child: Text(sort.label)),
          ],
        ),
      ],
      bottomBar: FilledButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateTripScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Plan a new trip'),
      ),
      child: Column(
        children: [
          if (trips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: FpSpace.sm),
              child: TextField(
                controller: _search,
                autofillHints: const [],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search by name or notes',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                        ),
                ),
              ),
            ),
          Expanded(
            child: trips.isEmpty
                ? FpEmptyState(
                    art: FpImages.emptyNoSavedTrips,
                    title: 'No saved trips',
                    message:
                        'Plans you create are stored here on the device. Each '
                        'one keeps its own gear, food and budget so you can '
                        'reuse it later.',
                    action: FilledButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CreateTripScreen(),
                        ),
                      ),
                      child: const Text('Plan your first trip'),
                    ),
                  )
                : visible.isEmpty
                ? FpEmptyState(
                    art: FpImages.emptyNoRouteData,
                    title: 'Nothing matches',
                    message:
                        'No saved trip contains "${_search.text.trim()}". Try a '
                        'shorter search.',
                    artSize: 160,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: FpSpace.md),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: FpSpace.xs),
                    itemBuilder: (context, index) {
                      final trip = visible[index];
                      return Slidable(
                        key: ValueKey(trip.id),
                        endActionPane: ActionPane(
                          motion: const DrawerMotion(),
                          extentRatio: 0.5,
                          children: [
                            SlidableAction(
                              onPressed: (_) => _duplicate(trip),
                              backgroundColor: FpColors.forestTint,
                              foregroundColor: FpColors.forestDeep,
                              icon: Icons.copy_rounded,
                              label: 'Duplicate',
                              borderRadius: FpRadius.cardAll,
                            ),
                            SlidableAction(
                              onPressed: (_) => _delete(trip),
                              backgroundColor: const Color(0x22C4462F),
                              foregroundColor: FpColors.severe,
                              icon: Icons.delete_outline_rounded,
                              label: 'Delete',
                              borderRadius: FpRadius.cardAll,
                            ),
                          ],
                        ),
                        child: _ArchiveCard(trip: trip),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ArchiveCard extends ConsumerWidget {
  const _ArchiveCard({required this.trip});

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
          FpArt(difficultyArt(analysis.difficulty.tier), size: 48, height: 54),
          const SizedBox(width: FpSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.name,
                  style: FpTypography.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  trip.plannedDate == null
                      ? 'Updated ${format.date(trip.updatedAt)}'
                      : format.date(trip.plannedDate),
                  style: FpTypography.caption,
                ),
                const SizedBox(height: FpSpace.xxs),
                Wrap(
                  spacing: FpSpace.xs,
                  runSpacing: 2,
                  children: [
                    Text(
                      format.distance(trip.distanceKm),
                      style: FpTypography.label,
                    ),
                    Text(
                      format.elevation(trip.elevationGainM),
                      style: FpTypography.label,
                    ),
                    Text(
                      format.duration(trip.movingMinutes),
                      style: FpTypography.label,
                    ),
                    if (analysis.load.totalKg > 0)
                      Text(
                        format.weight(analysis.load.totalKg),
                        style: FpTypography.label,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: FpSpace.xs),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (analysis.difficulty.confidence > 0)
                FpTag(label: analysis.difficulty.tier.label, color: color)
              else
                const FpTag(label: 'Draft', color: FpColors.graphiteSoft),
              const SizedBox(height: FpSpace.xxs),
              Text(
                '${format.percent(analysis.completeness)} planned',
                style: FpTypography.caption.copyWith(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
