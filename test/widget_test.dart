import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:featherpeakfurygame/core/design/fp_typography.dart';
import 'package:featherpeakfurygame/core/theme/fp_theme.dart';

void main() {
  test('theme uses the bundled Inter family as its default', () {
    final theme = FpTheme.build();
    expect(theme.textTheme.bodyMedium?.fontFamily, FpFonts.text);
  });

  test('display styles use the bundled Outfit family', () {
    expect(FpTypography.heroMetric.fontFamily, FpFonts.display);
    expect(FpTypography.titleLarge.fontFamily, FpFonts.display);
  });

  test('metric styles use tabular figures so number columns stay aligned', () {
    expect(
      FpTypography.metric.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  test('legal pages are locked to black on white', () {
    final theme = FpTheme.build();
    expect(theme.colorScheme.brightness, Brightness.light);
  });
}
