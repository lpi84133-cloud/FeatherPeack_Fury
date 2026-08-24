import 'dart:math' as math;

import '../models/trip.dart';

/// EggPack. One Egg Unit stands for one regular meal portion; what goes into it
/// is the user's decision, which keeps the estimate usable for any kind of food.
class FoodEstimate {
  const FoodEstimate({
    required this.baseUnits,
    required this.intensityUnits,
    required this.reserveUnits,
    required this.people,
    required this.movingHours,
  });

  /// One portion per person per block of active time.
  final int baseUnits;

  /// Extra portions produced by the intensity multiplier.
  final int intensityUnits;

  /// A safety margin added only on longer days.
  final int reserveUnits;

  final int people;
  final double movingHours;

  static const hoursPerUnit = 4.0;
  static const reserveThresholdHours = 6.0;
  static const approxKgPerUnit = 0.15;

  int get totalUnits => baseUnits + intensityUnits + reserveUnits;

  double get unitsPerPerson => people == 0 ? 0 : totalUnits / people;

  /// Rough packed weight of the recommended food, so the estimate can be
  /// carried straight over into the load plan.
  double get approxWeightKg => totalUnits * approxKgPerUnit;

  static FoodEstimate? of(Trip trip) {
    final hours = trip.movingHours;
    if (hours == null || hours <= 0) return null;

    final blocks = math.max(1, (hours / hoursPerUnit).ceil());
    final base = blocks * trip.people;
    final withIntensity = (base * trip.intensity.foodFactor).ceil();
    final reserve = hours >= reserveThresholdHours ? trip.people : 0;

    return FoodEstimate(
      baseUnits: base,
      intensityUnits: math.max(0, withIntensity - base),
      reserveUnits: reserve,
      people: trip.people,
      movingHours: hours,
    );
  }
}
