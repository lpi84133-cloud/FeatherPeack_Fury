import 'package:flutter/material.dart';

import '../../core/design/fp_colors.dart';
import '../../core/design/fp_images.dart';
import '../../domain/calc/trip_analysis.dart';

/// The stages of preparing a trip, in the order they build on each other. The
/// last one is the summary card, drawn as the summit of the trail.
enum WorkspaceSection {
  route(
    'Route',
    'Route Analyzer',
    FpImages.markerAscentSign,
    Icons.route_rounded,
    FpColors.forest,
  ),
  peak(
    'Peak',
    'Peak Profile',
    FpImages.peakGreen,
    Icons.terrain_rounded,
    FpColors.forestMid,
  ),
  load(
    'Load',
    'Feather Load',
    FpImages.featherGreen,
    Icons.backpack_rounded,
    FpColors.forestSoft,
  ),
  food(
    'Food',
    'EggPack',
    FpImages.eggSingle,
    Icons.egg_rounded,
    FpColors.goldDeep,
  ),
  budget(
    'Budget',
    'CoinBudget',
    FpImages.coinStack,
    Icons.savings_rounded,
    FpColors.gold,
  ),
  zones(
    'Zones',
    'Fury Zones',
    FpImages.furySteepSign,
    Icons.warning_amber_rounded,
    FpColors.hard,
  ),
  card(
    'Card',
    'Offline Trip Card',
    FpImages.markerSummitPost,
    Icons.badge_rounded,
    FpColors.skyDeep,
  );

  const WorkspaceSection(
    this.shortLabel,
    this.title,
    this.art,
    this.icon,
    this.accent,
  );

  final String shortLabel;
  final String title;
  final String art;
  final IconData icon;
  final Color accent;

  /// Whether this stage has the data it needs. Drives the filled markers on the
  /// trail so progress reflects the plan, not visited screens.
  bool isFilled(TripAnalysis analysis) => switch (this) {
    WorkspaceSection.route => analysis.trip.hasRouteBasics,
    WorkspaceSection.peak => analysis.trip.elevationGainM != null,
    WorkspaceSection.load => analysis.trip.hasLoadData,
    WorkspaceSection.food => analysis.food != null,
    WorkspaceSection.budget => !analysis.budget.isEmpty,
    WorkspaceSection.zones => analysis.difficulty.confidence > 0,
    WorkspaceSection.card => analysis.isComplete,
  };
}
