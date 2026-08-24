import 'package:flutter/material.dart';

/// Palette sampled directly from the Featherpeak Fury artwork: logo greens and
/// golds, the olive graphite of the gear renders, warm paper cream and the sky
/// gradient of the boot illustration.
abstract final class FpColors {
  /// Forest — primary brand family, used for elevation, peaks and primary actions.
  static const forestDeep = Color(0xFF14300C);
  static const forest = Color(0xFF24501C);
  static const forestMid = Color(0xFF386030);
  static const forestSoft = Color(0xFF6E8F5C);
  static const forestTint = Color(0xFFE7EEE1);

  /// Graphite — text and structural strokes.
  static const graphite = Color(0xFF23282B);
  static const graphiteMid = Color(0xFF4A5257);
  static const graphiteSoft = Color(0xFF8A9299);

  /// Cream — canvas and card surfaces.
  static const canvas = Color(0xFFF7F3EA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF0E8D8);
  static const outline = Color(0xFFE2D9C6);
  static const outlineStrong = Color(0xFFCFC3AA);

  /// Gold — the Coin family: budget, totals, highlighted values.
  static const gold = Color(0xFFF0A008);
  static const goldDeep = Color(0xFFC9800A);
  static const goldSoft = Color(0xFFF8D040);
  static const goldTint = Color(0xFFFDF1D4);

  /// Sky — informational accents and water/hydration values.
  static const sky = Color(0xFF66BCEA);
  static const skyDeep = Color(0xFF3893DB);
  static const skyTint = Color(0xFFE4F2FB);

  /// Difficulty scale. Red is reserved for the most demanding tier only.
  static const easy = Color(0xFF7FAF5A);
  static const moderate = Color(0xFFF0A008);
  static const hard = Color(0xFFDB7A2B);
  static const severe = Color(0xFFC4462F);

  /// Legal and support pages are locked to black on white for legibility and
  /// must not follow any other surface colour.
  static const legalText = Color(0xFF111111);
  static const legalSurface = Color(0xFFFFFFFF);
}
