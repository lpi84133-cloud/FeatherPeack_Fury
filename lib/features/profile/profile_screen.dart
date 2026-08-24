import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/audio/fp_feedback.dart';
import '../../core/design/fp_colors.dart';
import '../../core/design/fp_images.dart';
import '../../core/design/fp_tokens.dart';
import '../../core/design/fp_typography.dart';
import '../../data/providers.dart';
import '../../domain/models/hiker_profile.dart';
import '../../shared/widgets/fp_action_row.dart';
import '../../shared/widgets/fp_art.dart';
import '../../shared/widgets/fp_avatar.dart';
import '../../shared/widgets/fp_card.dart';
import '../../shared/widgets/fp_inputs.dart';
import '../../shared/widgets/fp_metric.dart';
import '../../shared/widgets/fp_screen.dart';
import '../../shared/widgets/fp_section_header.dart';
import 'avatar_framer.dart';

/// Hiker profile. Body weight is the load reference for every trip, so this
/// screen feeds the calculations rather than just storing a name.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _homeArea;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    _name = TextEditingController(text: profile.name);
    _homeArea = TextEditingController(text: profile.homeArea);
  }

  @override
  void dispose() {
    _name.dispose();
    _homeArea.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 92,
      );
      if (picked == null || !mounted) return;

      final bytes = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(
          builder: (_) => AvatarFramer(file: File(picked.path)),
        ),
      );
      if (bytes == null || !mounted) return;

      await ref.read(profileProvider.notifier).setAvatar(bytes);
      FpFeedback.instance.success(FpSound.successfulAction);
    } on Object {
      if (!mounted) return;
      FpFeedback.instance.warn();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'The camera is not available. Check camera access for '
                      'Featherpeak Fury in the system settings.'
                : 'Your photo library is not available. Check photo access for '
                      'Featherpeak Fury in the system settings.',
          ),
        ),
      );
    }
  }

  Future<void> _openAvatarMenu() async {
    final profile = ref.read(profileProvider);
    final hasPhoto = profile.avatarFileName != null;

    FpFeedback.instance.play(FpSound.menuOpen);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FpSheetHeader(
              title: 'Profile photo',
              description:
                  'Used only inside this app, stored only on this device.',
            ),
            FpActionRow(
              icon: Icons.photo_camera_outlined,
              label: 'Take a photo',
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            FpActionRow(
              icon: Icons.photo_library_outlined,
              label: 'Choose from library',
              onTap: () => Navigator.pop(context, 'library'),
            ),
            if (hasPhoto)
              FpActionRow(
                icon: Icons.delete_outline_rounded,
                label: 'Remove photo',
                color: FpColors.severe,
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            const SizedBox(height: FpSpace.xs),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    FpFeedback.instance.play(FpSound.menuClose);

    switch (choice) {
      case 'camera':
        await _pickAvatar(ImageSource.camera);
      case 'library':
        await _pickAvatar(ImageSource.gallery);
      case 'remove':
        await ref.read(profileProvider.notifier).removeAvatar();
        FpFeedback.instance.play(FpSound.removeItem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final format = ref.watch(formatProvider);
    final stats = ref.watch(archiveStatsProvider);
    final controller = ref.read(profileProvider.notifier);

    return FpScreen(
      title: 'Hiker profile',
      subtitle: 'Feeds the load and difficulty calculations',
      child: ListView(
        padding: const EdgeInsets.only(bottom: FpSpace.xl),
        children: [
          FpCard(
            padding: const EdgeInsets.all(FpSpace.md),
            child: Row(
              children: [
                Stack(
                  children: [
                    FpAvatar(size: 92, onTap: _openAvatarMenu),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: FpRoundButton(
                        icon: Icons.photo_camera_rounded,
                        size: 32,
                        background: FpColors.forest,
                        foreground: Colors.white,
                        tooltip: 'Change photo',
                        onPressed: _openAvatarMenu,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: FpSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.hasName ? profile.name : 'Add your name',
                        style: FpTypography.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile.avatarFileName == null
                            ? 'Tap the circle to add a photo from the camera or '
                                  'your library.'
                            : 'Photo stored in the app folder on this device.',
                        style: FpTypography.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: FpSpace.md),
          const FpSectionHeader(label: 'About you'),
          const SizedBox(height: FpSpace.xs),
          FpCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FpFieldLabel(text: 'Name', optional: true),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [],
                  decoration: const InputDecoration(
                    hintText: 'Shown on this screen only',
                    isDense: true,
                  ),
                  style: FpTypography.bodyStrong,
                  onChanged: controller.setName,
                ),
                const SizedBox(height: FpSpace.sm),
                const FpFieldLabel(text: 'Usual area', optional: true),
                TextField(
                  controller: _homeArea,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [],
                  decoration: const InputDecoration(
                    hintText: 'Dolomites, Cairngorms, Sierra…',
                    isDense: true,
                  ),
                  style: FpTypography.bodyStrong,
                  onChanged: controller.setHomeArea,
                ),
              ],
            ),
          ),
          const SizedBox(height: FpSpace.md),
          const FpSectionHeader(label: 'Load reference'),
          const SizedBox(height: FpSpace.xs),
          FpCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const FpArt(FpImages.featherCream, size: 40, height: 54),
                    const SizedBox(width: FpSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BODY WEIGHT', style: FpTypography.overline),
                          Text(
                            format.weight(profile.bodyWeightKg),
                            style: FpTypography.metric,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: profile.bodyWeightKg.clamp(
                    HikerProfile.minBodyWeightKg,
                    HikerProfile.maxBodyWeightKg,
                  ),
                  min: HikerProfile.minBodyWeightKg,
                  max: HikerProfile.maxBodyWeightKg,
                  divisions:
                      (HikerProfile.maxBodyWeightKg -
                              HikerProfile.minBodyWeightKg)
                          .round(),
                  label: format.weight(profile.bodyWeightKg),
                  onChanged: controller.setBodyWeight,
                ),
                const SizedBox(height: FpSpace.xs),
                FpValueRow(
                  label: 'Comfortable pack · 15%',
                  value: format.weight(profile.comfortableLoadKg),
                  icon: Icons.check_circle_outline_rounded,
                ),
                FpValueRow(
                  label: 'Upper comfortable limit · 20%',
                  value: format.weight(profile.maxRecommendedLoadKg),
                  icon: Icons.trending_up_rounded,
                ),
                FpValueRow(
                  label: 'Heavy load threshold · 25%',
                  value: format.weight(profile.heavyLoadKg),
                  icon: Icons.warning_amber_rounded,
                  valueColor: FpColors.hard,
                ),
                const SizedBox(height: FpSpace.xs),
                const FpNotice(
                  message:
                      'Day-hiking guidance puts a comfortable pack at 15–20% of '
                      'body weight. Feather Load and Fury Zones both compare '
                      'your pack against these figures.',
                ),
              ],
            ),
          ),
          const SizedBox(height: FpSpace.md),
          const FpSectionHeader(label: 'Your planning record'),
          const SizedBox(height: FpSpace.xs),
          if (stats.isEmpty)
            FpCard(
              child: Row(
                children: [
                  const FpArt(FpImages.chickenPacked, size: 48, height: 56),
                  const SizedBox(width: FpSpace.sm),
                  Expanded(
                    child: Text(
                      'Once you save trips, their totals appear here — real '
                      'numbers from your own plans, nothing awarded.',
                      style: FpTypography.body,
                    ),
                  ),
                ],
              ),
            )
          else
            FpCard(
              child: Column(
                children: [
                  FpValueRow(
                    label: 'Trips planned',
                    value: '${stats.tripCount}',
                    icon: Icons.map_outlined,
                  ),
                  FpValueRow(
                    label: 'Total distance planned',
                    value: format.distance(stats.totalDistanceKm),
                    icon: Icons.straighten_rounded,
                  ),
                  FpValueRow(
                    label: 'Total climb planned',
                    value: format.elevation(stats.totalElevationM),
                    icon: Icons.terrain_rounded,
                  ),
                  FpValueRow(
                    label: 'Average difficulty',
                    value: '${stats.averageDifficulty} / 100',
                    icon: Icons.speed_rounded,
                  ),
                  FpValueRow(
                    label: 'Dated in the future',
                    value: '${stats.plannedAhead}',
                    icon: Icons.event_available_rounded,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
