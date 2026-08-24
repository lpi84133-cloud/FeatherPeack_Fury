import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/fp_feedback.dart';
import '../../core/design/fp_colors.dart';
import '../../core/design/fp_tokens.dart';
import '../../core/design/fp_typography.dart';
import '../../data/providers.dart';
import '../../domain/calc/trip_analysis.dart';
import '../../domain/models/trip.dart';
import '../../shared/widgets/fp_action_row.dart';
import '../../shared/widgets/fp_metric.dart';
import '../../shared/widgets/fp_screen.dart';
import '../card/trip_card_view.dart';
import '../coin/coin_budget_view.dart';
import '../egg/egg_pack_view.dart';
import '../feather/feather_load_view.dart';
import '../fury/fury_zones_view.dart';
import '../peak/peak_profile_view.dart';
import '../peak/route_analyzer_view.dart';
import 'create_trip_screen.dart';
import 'trail_spine.dart';
import 'workspace_section.dart';

/// The single screen the user works in once a trip exists. The trail on the left
/// switches stages; the stage itself fills the rest of the page.
class TripWorkspaceScreen extends ConsumerStatefulWidget {
  const TripWorkspaceScreen({
    required this.tripId,
    this.initialSection = WorkspaceSection.route,
    super.key,
  });

  final String tripId;
  final WorkspaceSection initialSection;

  @override
  ConsumerState<TripWorkspaceScreen> createState() =>
      _TripWorkspaceScreenState();
}

class _TripWorkspaceScreenState extends ConsumerState<TripWorkspaceScreen> {
  late WorkspaceSection _section = widget.initialSection;

  Future<void> _editParameters(Trip trip) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CreateTripScreen(existing: trip)),
    );
  }

  Future<void> _openMenu(Trip trip) async {
    FpFeedback.instance.play(FpSound.menuOpen);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FpSheetHeader(title: trip.name, description: 'Trip options'),
            FpActionRow(
              icon: Icons.tune_rounded,
              label: 'Edit parameters',
              description: 'Distance, climb, time, terrain, group',
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            FpActionRow(
              icon: Icons.copy_rounded,
              label: 'Duplicate as template',
              description: 'Reuse this gear, food and budget for a new trip',
              onTap: () => Navigator.pop(context, 'duplicate'),
            ),
            FpActionRow(
              icon: Icons.delete_outline_rounded,
              label: 'Delete trip',
              description: 'Removes it from this device',
              color: FpColors.severe,
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            const SizedBox(height: FpSpace.xs),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    FpFeedback.instance.play(FpSound.menuClose);

    switch (action) {
      case 'edit':
        await _editParameters(trip);
      case 'duplicate':
        final copy = await ref.read(tripsProvider.notifier).duplicate(trip);
        if (!mounted) return;
        FpFeedback.instance.success(FpSound.saveTrip);
        await ref.read(currentTripIdProvider.notifier).select(copy.id);
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TripWorkspaceScreen(tripId: copy.id),
          ),
        );
      case 'delete':
        final confirmed = await _confirmDelete(trip);
        if (!confirmed || !mounted) return;
        await ref.read(tripsProvider.notifier).delete(trip.id);
        if (!mounted) return;
        Navigator.of(context).pop();
    }
  }

  Future<bool> _confirmDelete(Trip trip) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this trip?'),
        content: Text(
          '"${trip.name}" and everything in it will be removed from this '
          'device. This cannot be undone.',
        ),
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
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // Watching the list, not the notifier: edits made inside the workspace have
    // to redraw the stage that made them.
    final trips = ref.watch(tripsProvider);
    final trip = trips.where((entry) => entry.id == widget.tripId).firstOrNull;
    if (trip == null) {
      // The trip was deleted from elsewhere; leave rather than show a shell.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const Scaffold();
    }

    final analysis = ref.watch(analysisProvider(trip));
    final format = ref.watch(formatProvider);

    return FpScreen(
      title: trip.name,
      subtitle:
          '${_section.title} · '
          '${trip.plannedDate == null ? 'No date set' : format.date(trip.plannedDate)}',
      actions: [
        FpRoundButton(
          icon: Icons.tune_rounded,
          tooltip: 'Edit parameters',
          onPressed: () => _editParameters(trip),
        ),
        FpRoundButton(
          icon: Icons.more_horiz_rounded,
          tooltip: 'Trip options',
          onPressed: () => _openMenu(trip),
        ),
      ],
      padding: EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: FpSpace.xxs,
              top: FpSpace.xs,
              bottom: FpSpace.xs,
            ),
            child: TrailSpine(
              analysis: analysis,
              current: _section,
              onSelect: (section) => setState(() => _section = section),
            ),
          ),
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: FpColors.outline)),
              ),
              child: AnimatedSwitcher(
                duration: FpMotion.base,
                switchInCurve: FpMotion.curve,
                child: KeyedSubtree(
                  key: ValueKey(_section),
                  child: _SectionBody(
                    section: _section,
                    trip: trip,
                    analysis: analysis,
                    onSectionRequested: (section) =>
                        setState(() => _section = section),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({
    required this.section,
    required this.trip,
    required this.analysis,
    required this.onSectionRequested,
  });

  final WorkspaceSection section;
  final Trip trip;
  final TripAnalysis analysis;
  final ValueChanged<WorkspaceSection> onSectionRequested;

  @override
  Widget build(BuildContext context) {
    final body = switch (section) {
      WorkspaceSection.route => RouteAnalyzerView(analysis: analysis),
      WorkspaceSection.peak => PeakProfileView(analysis: analysis),
      WorkspaceSection.load => FeatherLoadView(analysis: analysis),
      WorkspaceSection.food => EggPackView(analysis: analysis),
      WorkspaceSection.budget => CoinBudgetView(analysis: analysis),
      WorkspaceSection.zones => FuryZonesView(analysis: analysis),
      WorkspaceSection.card => TripCardView(
        analysis: analysis,
        onSectionRequested: onSectionRequested,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
              Expanded(
                child: Text(section.title, style: FpTypography.titleLarge),
              ),
              if (!section.isFilled(analysis))
                const FpTag(label: 'Incomplete', color: FpColors.graphiteSoft),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}
