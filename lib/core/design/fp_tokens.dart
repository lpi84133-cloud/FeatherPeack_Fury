import 'package:flutter/material.dart';

import 'fp_colors.dart';

/// Spacing scale. Every gap in the app comes from here so the vertical rhythm
/// of the trail-spine layout stays consistent.
abstract final class FpSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 28.0;
  static const xxl = 40.0;
}

/// Corner radii. Large soft rounding carries the "premium outdoor" feel.
abstract final class FpRadius {
  static const tile = 18.0;
  static const card = 24.0;
  static const hero = 32.0;
  static const sheet = 28.0;
  static const pill = 999.0;

  static const tileAll = BorderRadius.all(Radius.circular(tile));
  static const cardAll = BorderRadius.all(Radius.circular(card));
  static const heroAll = BorderRadius.all(Radius.circular(hero));
  static const pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Soft, low-contrast shadows. Nothing heavier than [lifted] anywhere.
abstract final class FpShadow {
  static const soft = <BoxShadow>[
    BoxShadow(
      color: Color(0x0F23282B),
      blurRadius: 14,
      offset: Offset(0, 4),
    ),
  ];

  static const lifted = <BoxShadow>[
    BoxShadow(
      color: Color(0x1423282B),
      blurRadius: 28,
      offset: Offset(0, 10),
    ),
  ];
}

/// Motion durations. Kept short: this is a utility, not a showreel.
abstract final class FpMotion {
  static const fast = Duration(milliseconds: 140);
  static const base = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 380);

  static const curve = Curves.easeOutCubic;
}

/// Border presets for cards and tiles.
abstract final class FpBorders {
  static const hairline = BorderSide(color: FpColors.outline);
  static const strong = BorderSide(color: FpColors.outlineStrong);
}
