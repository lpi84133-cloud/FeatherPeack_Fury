import 'package:flutter/material.dart';

import 'fp_colors.dart';

/// Both families are bundled in `assets/fonts`, so text renders identically on
/// the very first launch with no network access.
abstract final class FpFonts {
  /// Geometric display face for headings and large metric numbers.
  static const display = 'Outfit';

  /// UI face for labels, body copy and dense tabular data.
  static const text = 'Inter';
}

abstract final class FpTypography {
  /// Tabular figures keep number columns from shifting as values change.
  static const _tabular = <FontFeature>[FontFeature.tabularFigures()];

  static const TextStyle heroMetric = TextStyle(
    fontFamily: FpFonts.display,
    fontSize: 56,
    height: 1.0,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.6,
    fontFeatures: _tabular,
    color: FpColors.graphite,
  );

  static const TextStyle metric = TextStyle(
    fontFamily: FpFonts.display,
    fontSize: 28,
    height: 1.1,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.6,
    fontFeatures: _tabular,
    color: FpColors.graphite,
  );

  static const TextStyle metricSmall = TextStyle(
    fontFamily: FpFonts.display,
    fontSize: 20,
    height: 1.15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    fontFeatures: _tabular,
    color: FpColors.graphite,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: FpFonts.display,
    fontSize: 24,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    color: FpColors.graphite,
  );

  static const TextStyle title = TextStyle(
    fontFamily: FpFonts.display,
    fontSize: 18,
    height: 1.25,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: FpColors.graphite,
  );

  static const TextStyle body = TextStyle(
    fontFamily: FpFonts.text,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: FpColors.graphiteMid,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: FpFonts.text,
    fontSize: 15,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: FpColors.graphite,
  );

  static const TextStyle label = TextStyle(
    fontFamily: FpFonts.text,
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w500,
    color: FpColors.graphiteMid,
  );

  /// Section eyebrows: short, wide-tracked, always uppercase in the UI.
  static const TextStyle overline = TextStyle(
    fontFamily: FpFonts.text,
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.4,
    color: FpColors.graphiteSoft,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: FpFonts.text,
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w400,
    color: FpColors.graphiteSoft,
  );

  static const TextStyle button = TextStyle(
    fontFamily: FpFonts.display,
    fontSize: 16,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  static const TextTheme textTheme = TextTheme(
    displayLarge: heroMetric,
    displayMedium: metric,
    displaySmall: metricSmall,
    headlineMedium: titleLarge,
    titleMedium: title,
    bodyLarge: bodyStrong,
    bodyMedium: body,
    bodySmall: caption,
    labelLarge: button,
    labelMedium: label,
    labelSmall: overline,
  );
}
