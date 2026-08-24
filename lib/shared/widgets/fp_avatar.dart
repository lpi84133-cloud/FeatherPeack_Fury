import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/fp_colors.dart';
import '../../core/design/fp_images.dart';
import '../../core/design/fp_typography.dart';
import '../../data/providers.dart';
import 'fp_art.dart';

/// Profile photo if the user picked one, their initials if they only entered a
/// name, and the mascot otherwise.
class FpAvatar extends ConsumerWidget {
  const FpAvatar({this.size = 44, this.onTap, super.key});

  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final file = ref.watch(profileRepositoryProvider).avatarFile(profile);

    Widget content;
    if (file != null) {
      content = Image.file(
        file,
        key: ValueKey(profile.avatarFileName),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        errorBuilder: (_, _, _) => const FpArt(FpImages.chickenStanding),
      );
    } else if (profile.hasName) {
      content = Center(
        child: Text(
          profile.initials,
          style: FpTypography.metricSmall.copyWith(
            fontSize: size * 0.36,
            color: FpColors.forestDeep,
          ),
        ),
      );
    } else {
      content = Padding(
        padding: EdgeInsets.all(size * 0.1),
        child: FpArt(FpImages.chickenStanding, size: size * 0.8),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: FpColors.forestTint,
        shape: const CircleBorder(
          side: BorderSide(color: FpColors.outlineStrong),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: content),
      ),
    );
  }
}
