import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/fp_feedback.dart';
import '../../core/design/fp_colors.dart';
import '../../core/design/fp_images.dart';
import '../../core/design/fp_tokens.dart';
import '../../core/design/fp_typography.dart';
import '../../data/providers.dart';
import '../../domain/models/trip.dart';
import '../../shared/widgets/fp_art.dart';
import '../../shared/widgets/fp_card.dart';
import '../../shared/widgets/fp_inputs.dart';
import '../../shared/widgets/fp_metric.dart';
import '../../shared/widgets/fp_screen.dart';
import '../../shared/widgets/fp_section_header.dart';
import 'trip_workspace_screen.dart';

/// Creates a trip or edits the parameters of an existing one. Values are typed
/// in the user's own units and converted to metric on save.
class CreateTripScreen extends ConsumerStatefulWidget {
  const CreateTripScreen({this.existing, super.key});

  final Trip? existing;

  @override
  ConsumerState<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends ConsumerState<CreateTripScreen> {
  late final TextEditingController _name;
  late final TextEditingController _notes;

  DateTime? _plannedDate;
  double? _distance;
  double? _elevation;
  int? _movingMinutes;
  Terrain? _terrain;
  double? _basePack;
  double? _water;
  late int _people;
  late Intensity _intensity;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final trip = widget.existing;
    final format = ref.read(formatProvider);

    _name = TextEditingController(text: trip?.name ?? '');
    _notes = TextEditingController(text: trip?.notes ?? '');
    _plannedDate = trip?.plannedDate;
    _distance = trip?.distanceKm == null
        ? null
        : format.kmToDistance(trip!.distanceKm!);
    _elevation = trip?.elevationGainM == null
        ? null
        : format.metresToElevation(trip!.elevationGainM!);
    _movingMinutes = trip?.movingMinutes;
    _terrain = trip?.terrain;
    _basePack = trip?.basePackKg == null
        ? null
        : format.kgToWeight(trip!.basePackKg!);
    _water = trip?.waterLitres == null
        ? null
        : format.litresToVolume(trip!.waterLitres!);
    _people = trip?.people ?? 1;
    _intensity = trip?.intensity ?? ref.read(settingsProvider).defaultIntensity;
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _plannedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: 'Planned start date',
    );
    if (picked != null) setState(() => _plannedDate = picked);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      FpFeedback.instance.warn();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give the trip a name to save it.')),
      );
      return;
    }

    final format = ref.read(formatProvider);
    final controller = ref.read(tripsProvider.notifier);
    final base = widget.existing ?? controller.createDraft(name: name);

    final trip = Trip(
      id: base.id,
      name: name,
      createdAt: base.createdAt,
      updatedAt: DateTime.now(),
      plannedDate: _plannedDate,
      distanceKm: _distance == null ? null : format.distanceToKm(_distance!),
      elevationGainM: _elevation == null
          ? null
          : format.elevationToMetres(_elevation!),
      movingMinutes: _movingMinutes,
      terrain: _terrain,
      basePackKg: _basePack == null ? null : format.weightToKg(_basePack!),
      waterLitres: _water == null ? null : format.volumeToLitres(_water!),
      people: _people,
      intensity: _intensity,
      notes: _notes.text.trim(),
      gear: base.gear,
      expenses: base.expenses,
    );

    await controller.save(trip);
    await ref.read(currentTripIdProvider.notifier).select(trip.id);
    if (!mounted) return;

    FpFeedback.instance.success(FpSound.saveTrip);
    if (_isEditing) {
      Navigator.of(context).pop();
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => TripWorkspaceScreen(tripId: trip.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final format = ref.watch(formatProvider);

    return FpScreen(
      title: _isEditing ? 'Edit parameters' : 'New trip',
      subtitle: _isEditing
          ? 'Changes recalculate everything on save'
          : 'Fill in what you know — you can add the rest later',
      bottomBar: Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: _save,
              child: Text(_isEditing ? 'Save changes' : 'Create trip'),
            ),
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: FpSpace.xl),
        children: [
          FpCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FpFieldLabel(text: 'Trip name'),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [],
                  decoration: const InputDecoration(
                    hintText: 'Pine Ridge Loop',
                    isDense: true,
                  ),
                  style: FpTypography.bodyStrong,
                ),
                const SizedBox(height: FpSpace.sm),
                const FpFieldLabel(text: 'Planned date', optional: true),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          alignment: Alignment.centerLeft,
                        ),
                        icon: const Icon(Icons.event_rounded, size: 18),
                        label: Text(
                          _plannedDate == null
                              ? 'Pick a date'
                              : format.date(_plannedDate),
                        ),
                      ),
                    ),
                    if (_plannedDate != null) ...[
                      const SizedBox(width: FpSpace.xs),
                      FpRoundButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Clear date',
                        onPressed: () => setState(() => _plannedDate = null),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: FpSpace.md),
          const FpSectionHeader(label: 'Peak — route'),
          const SizedBox(height: FpSpace.xs),
          FpCard(
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: FpNumberField(
                        label: 'Distance',
                        unit: format.distanceSymbol,
                        value: _distance,
                        max: 999,
                        onChanged: (value) => setState(() => _distance = value),
                      ),
                    ),
                    const SizedBox(width: FpSpace.sm),
                    Expanded(
                      child: FpNumberField(
                        label: 'Elevation gain',
                        unit: format.elevationSymbol,
                        value: _elevation,
                        decimals: 0,
                        max: 30000,
                        onChanged: (value) => setState(() => _elevation = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: FpSpace.sm),
                FpDurationField(
                  minutes: _movingMinutes,
                  onChanged: (value) => setState(() => _movingMinutes = value),
                ),
                const SizedBox(height: FpSpace.xxs),
                Text(
                  'Moving time only — leave out overnight stops so the food '
                  'estimate stays realistic.',
                  style: FpTypography.caption,
                ),
                const SizedBox(height: FpSpace.sm),
                FpChoiceGroup<Terrain>(
                  label: 'Terrain type',
                  options: [
                    for (final terrain in Terrain.values)
                      (terrain, terrain.label),
                  ],
                  selected: _terrain,
                  artFor: (terrain) => terrain.image,
                  onChanged: (value) => setState(() => _terrain = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: FpSpace.md),
          const FpSectionHeader(label: 'Group and effort'),
          const SizedBox(height: FpSpace.xs),
          FpCard(
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: FpStepper(
                        label: 'People',
                        value: _people,
                        onChanged: (value) => setState(() => _people = value),
                      ),
                    ),
                    const SizedBox(width: FpSpace.sm),
                    Expanded(
                      child: FpNumberField(
                        label: 'Water',
                        unit: format.volumeSymbol,
                        value: _water,
                        max: 99,
                        optional: true,
                        onChanged: (value) => setState(() => _water = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: FpSpace.sm),
                FpChoiceGroup<Intensity>(
                  label: 'Planned intensity',
                  options: [
                    for (final intensity in Intensity.values)
                      (intensity, intensity.label),
                  ],
                  selected: _intensity,
                  onChanged: (value) => setState(() => _intensity = value),
                ),
                const SizedBox(height: FpSpace.xxs),
                Text(
                  'Intensity only affects the recommended food reserve.',
                  style: FpTypography.caption,
                ),
              ],
            ),
          ),
          const SizedBox(height: FpSpace.md),
          const FpSectionHeader(label: 'Feather — base load'),
          const SizedBox(height: FpSpace.xs),
          FpCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const FpArt(FpImages.gearBackpack, size: 48),
                    const SizedBox(width: FpSpace.sm),
                    Expanded(
                      child: FpNumberField(
                        label: 'Pack and unlisted items',
                        unit: format.weightSymbol,
                        value: _basePack,
                        max: 200,
                        optional: true,
                        onChanged: (value) => setState(() => _basePack = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: FpSpace.xs),
                const FpNotice(
                  message:
                      'Individual gear is itemised later in Feather Load. Water '
                      'is counted automatically at 1 kg per litre.',
                ),
              ],
            ),
          ),
          const SizedBox(height: FpSpace.md),
          const FpSectionHeader(label: 'Notes'),
          const SizedBox(height: FpSpace.xs),
          FpCard(
            child: TextField(
              controller: _notes,
              minLines: 3,
              maxLines: 6,
              maxLength: 600,
              autofillHints: const [],
              decoration: const InputDecoration(
                hintText:
                    'Trailhead, parking, water sources, who to tell before you '
                    'leave…',
                isDense: true,
                counterStyle: TextStyle(color: FpColors.graphiteSoft),
              ),
              style: FpTypography.body,
            ),
          ),
        ],
      ),
    );
  }
}
