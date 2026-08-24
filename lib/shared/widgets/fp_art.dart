import 'package:flutter/material.dart';

/// Draws one of the bundled illustrations at a fixed box size, decoding it at
/// the resolution it is actually shown at to keep memory flat.
class FpArt extends StatelessWidget {
  const FpArt(
    this.asset, {
    this.size = 40,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.opacity = 1,
    super.key,
  });

  final String asset;
  final double size;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final image = Image.asset(
      asset,
      width: size,
      height: height ?? size,
      fit: fit,
      alignment: alignment,
      cacheWidth: (size * ratio).round(),
      filterQuality: FilterQuality.medium,
    );
    return opacity == 1 ? image : Opacity(opacity: opacity, child: image);
  }
}
