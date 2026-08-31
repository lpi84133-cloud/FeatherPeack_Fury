import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_info.dart';
import '../../core/audio/fp_feedback.dart';
import '../../core/design/fp_colors.dart';
import '../../core/design/fp_images.dart';
import '../../core/design/fp_tokens.dart';
import '../../core/design/fp_typography.dart';
import '../../core/storage/fp_storage.dart';
import '../../data/providers.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/trip.dart';
import '../../shared/widgets/fp_action_row.dart';
import '../../shared/widgets/fp_art.dart';
import '../../shared/widgets/fp_card.dart';
import '../../shared/widgets/fp_inputs.dart';
import '../../shared/widgets/fp_metric.dart';
import '../../shared/widgets/fp_screen.dart';
import '../../shared/widgets/fp_section_header.dart';
import '../legal/legal_screen.dart';

/// Settings that change how the app behaves — units, defaults, feedback and
/// local data. Nothing here is a placeholder switch.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int? _usedBytes;

  @override
  void initState() {
    super.initState();
    _measureStorage();
  }

  Future<void> _measureStorage() async {
    final bytes = await FpStorage.usedBytes();
    if (mounted) setState(() => _usedBytes = bytes);
  }

  Future<void> _deleteAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text(
          'Every saved trip, your profile, your photo and all preferences will '
          'be erased from this device. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: FpColors.severe),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(tripsProvider.notifier).deleteAll();
    await ref.read(profileProvider.notifier).removeAvatar();
    await FpStorage.clearAll();
    await ref.read(currentTripIdProvider.notifier).select(null);
    ref.invalidate(profileProvider);
    ref.invalidate(settingsProvider);

    FpFeedback.instance.warn();
    await _measureStorage();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All local data deleted.')),
    );
  }

  void _openLegal(LegalPage page) {
    FpFeedback.instance.play(FpSound.screenOpen);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LegalScreen(page: page)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final format = ref.watch(formatProvider);
    final trips = ref.watch(tripsProvider);

    return FpScreen(
      title: 'Settings',
      subtitle: 'Units, defaults and local data',
      child: ListView(
        padding: const EdgeInsets.only(bottom: FpSpace.xl),
        children: [
          const FpSectionHeader(label: 'Units'),
          const SizedBox(height: FpSpace.xs),
          FpCard(
            child: Column(
              children: [
                FpChoiceGroup<DistanceUnit>(
                  label: 'Distance',
                  options: [
                    for (final unit in DistanceUnit.values)
                      (unit, unit.label),
                  ],
                  selected: settings.distanceUnit,
                  onChanged: controller.setDistanceUnit,
                ),
                const SizedBox(height: FpSpace.sm),
                FpChoiceGroup<ElevationUnit>(
                  label: 'Elevation',
                  options: [
                    for (final unit in ElevationUnit.values)
                      (unit, unit.label),
                  ],
                  selected: settings.elevationUnit,
                  onChanged: controller.setElevationUnit,
                ),
                const SizedBox(height: FpSpace.sm),
                FpChoiceGroup<WeightUnit>(
                  label: 'Weight',
                  options: [
                    for (final unit in WeightUnit.values) (unit, unit.label),
                  ],
                  selected: settings.weightUnit,
                  onChanged: controller.setWeightUnit,
                ),
                const SizedBox(height: FpSpace.sm),
                FpChoiceGroup<VolumeUnit>(
                  label: 'Volume',
                  options: [
                    for (final unit in VolumeUnit.values) (unit, unit.label),
                  ],
                  selected: settings.volumeUnit,
                  onChanged: controller.setVolumeUnit,
                ),
                const SizedBox(height: FpSpace.xs),
                const FpNotice(
                  message:
                      'Trips are stored in metric and converted for display, so '
                      'switching units never changes your saved numbers.',
                ),
              ],
            ),
          ),
          const SizedBox(height: FpSpace.md),
          const FpSectionHeader(label: 'Budget and time'),
          const SizedBox(height: FpSpace.xs),
          FpCard(
            child: Column(
              children: [
                FpChoiceGroup<String>(
                  label: 'Currency symbol',
                  options: [
                    for (final symbol in AppSettings.currencyChoices)
                      (symbol, symbol),
                  ],
                  selected: settings.currencySymbol,
                  onChanged: controller.setCurrencySymbol,
                ),
                const SizedBox(height: FpSpace.sm),
                FpChoiceGroup<TimeFormat>(
                  label: 'Time format',
                  options: [
                    for (final value in TimeFormat.values)
                      (value, value.label),
                  ],
                  selected: settings.timeFormat,
                  onChanged: controller.setTimeFormat,
                ),
              ],
            ),
          ),
          const SizedBox(height: FpSpace.md),
          const FpSectionHeader(label: 'Planning defaults'),
          const SizedBox(height: FpSpace.xs),
          FpCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FpChoiceGroup<Intensity>(
                  label: 'Intensity for new trips',
                  options: [
                    for (final value in Intensity.values) (value, value.label),
                  ],
                  selected: settings.defaultIntensity,
                  onChanged: controller.setDefaultIntensity,
                ),
                const SizedBox(height: FpSpace.xxs),
                Text(
                  'Applied to trips you create from now on. Existing trips keep '
                  'their own setting.',
                  style: FpTypography.caption,
                ),
              ],
            ),
          ),
          const SizedBox(height: FpSpace.md),
          const FpSectionHeader(label: 'Sound and haptics'),
          const SizedBox(height: FpSpace.xs),
          FpCard(
            padding: const EdgeInsets.symmetric(horizontal: FpSpace.sm),
            child: Column(
              children: [
                FpSwitchRow(
                  label: 'Interface sounds',
                  description:
                      'Short cues on save, add and warnings. Mixes with your '
                      'music rather than interrupting it.',
                  value: settings.soundEnabled,
                  onChanged: (value) {
                    controller.setSoundEnabled(value);
                    if (value) FpFeedback.instance.play(FpSound.buttonTap);
                  },
                ),
                const Divider(height: 1),
                FpSwitchRow(
                  label: 'Haptics',
                  description: 'A light tap on selections and confirmations.',
                  value: settings.hapticsEnabled,
                  onChanged: (value) {
                    controller.setHapticsEnabled(value);
                    if (value) FpFeedback.instance.tap();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: FpSpace.md),
          const FpSectionHeader(label: 'Data and storage'),
          const SizedBox(height: FpSpace.xs),
          FpCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FpValueRow(
                  label: 'Saved trips',
                  value: '${trips.length}',
                  icon: Icons.folder_outlined,
                ),
                FpValueRow(
                  label: 'Gear items listed',
                  value: '${trips.fold<int>(0, (sum, t) => sum + t.gear.length)}',
                  icon: Icons.backpack_outlined,
                ),
                FpValueRow(
                  label: 'Space used on this device',
                  value: _usedBytes == null
                      ? 'Measuring…'
                      : format.bytes(_usedBytes!),
                  icon: Icons.sd_storage_outlined,
                ),
                const SizedBox(height: FpSpace.sm),
                OutlinedButton.icon(
                  onPressed: () async {
                    await controller.resetToDefaults();
                    FpFeedback.instance.success(FpSound.successfulAction);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Preferences reset. Trips are untouched.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Reset preferences'),
                ),
                const SizedBox(height: FpSpace.xs),
                OutlinedButton.icon(
                  onPressed: _deleteAllData,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FpColors.severe,
                    side: const BorderSide(color: FpColors.severe),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete all data'),
                ),
              ],
            ),
          ),
          const SizedBox(height: FpSpace.md),
          const FpSectionHeader(label: 'Help and legal'),
          const SizedBox(height: FpSpace.xs),
          FpCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final page in LegalPage.values) ...[
                  FpActionRow(
                    icon: switch (page) {
                      LegalPage.privacy => Icons.privacy_tip_outlined,
                      LegalPage.support => Icons.support_agent_outlined,
                      LegalPage.faq => Icons.calculate_outlined,
                    },
                    label: page.title,
                    description: page.subtitle,
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: FpColors.graphiteSoft,
                    ),
                    onTap: () => _openLegal(page),
                  ),
                  if (page != LegalPage.values.last)
                    const Divider(height: 1, indent: FpSpace.md),
                ],
              ],
            ),
          ),
          const SizedBox(height: FpSpace.sm),
          const FpNotice(
            message:
                'All three pages are stored inside the app and open with no '
                'connection.',
            icon: Icons.wifi_off_rounded,
          ),
          const SizedBox(height: FpSpace.md),
          const FpSectionHeader(label: 'About'),
          const SizedBox(height: FpSpace.xs),
          FpCard(
            child: Column(
              children: [
                Row(
                  children: [
                    const FpArt(FpImages.wordmark, size: 120, height: 52),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('VERSION', style: FpTypography.overline),
                        Text(
                          AppInfo.version,
                          style: FpTypography.metricSmall.copyWith(fontSize: 18),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: FpSpace.lg),
                Text(
                  '${AppInfo.name} is an offline utility for preparing hiking '
                  'trips. It has no account system, no server and no tracking: '
                  'every calculation runs on this device and every value you '
                  'enter stays here.',
                  style: FpTypography.body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
