import '../models/hiker_profile.dart';
import '../models/trip.dart';
import 'budget_breakdown.dart';
import 'difficulty.dart';
import 'food_estimate.dart';
import 'fury_zones.dart';
import 'load_breakdown.dart';
import 'peak_profile.dart';

/// A parameter the analysis still needs, phrased so the UI can tell the user
/// exactly what is missing instead of hiding behind a partial number.
enum MissingInput {
  distance('Distance', 'the difficulty score and the route profile'),
  elevation('Elevation gain', 'the climb analysis and the peak profile'),
  duration('Moving time', 'the food estimate and the long-day check'),
  terrain('Terrain type', 'the surface part of the difficulty score'),
  load('Pack weight', 'the load analysis and the pack balance check'),
  water('Water volume', 'the hydration check'),
  expenses('Expenses', 'the budget');

  const MissingInput(this.label, this.affects);

  final String label;
  final String affects;
}

/// Everything the app computes for one trip, in one place. Pure and
/// synchronous: no storage, no I/O, no clock.
class TripAnalysis {
  const TripAnalysis({
    required this.trip,
    required this.difficulty,
    required this.load,
    required this.food,
    required this.budget,
    required this.profile,
    required this.fury,
    required this.missing,
  });

  final Trip trip;
  final DifficultyResult difficulty;
  final LoadResult load;
  final FoodEstimate? food;
  final BudgetResult budget;
  final PeakProfileResult? profile;
  final FuryResult fury;
  final List<MissingInput> missing;

  bool get isComplete => missing.isEmpty;

  /// Share of the planning inputs that are filled in, 0..1.
  double get completeness =>
      1 - missing.length / MissingInput.values.length;

  static TripAnalysis of(Trip trip, HikerProfile hiker) {
    final difficulty = DifficultyResult.of(trip, hiker);
    final load = LoadResult.of(trip, hiker);
    final food = FoodEstimate.of(trip);

    return TripAnalysis(
      trip: trip,
      difficulty: difficulty,
      load: load,
      food: food,
      budget: BudgetResult.of(trip),
      profile: PeakProfileResult.of(trip),
      fury: FuryResult.of(trip, hiker, difficulty, load, food),
      missing: [
        if (trip.distanceKm == null) MissingInput.distance,
        if (trip.elevationGainM == null) MissingInput.elevation,
        if (trip.movingMinutes == null) MissingInput.duration,
        if (trip.terrain == null) MissingInput.terrain,
        if (!trip.hasLoadData) MissingInput.load,
        if (trip.waterLitres == null) MissingInput.water,
        if (trip.expenses.isEmpty) MissingInput.expenses,
      ],
    );
  }
}
