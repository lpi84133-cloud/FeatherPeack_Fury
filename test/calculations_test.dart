import 'package:flutter_test/flutter_test.dart';

import 'package:featherpeakfurygame/domain/calc/budget_breakdown.dart';
import 'package:featherpeakfurygame/domain/calc/difficulty.dart';
import 'package:featherpeakfurygame/domain/calc/food_estimate.dart';
import 'package:featherpeakfurygame/domain/calc/fury_zones.dart';
import 'package:featherpeakfurygame/domain/calc/load_breakdown.dart';
import 'package:featherpeakfurygame/domain/calc/moving_time_estimate.dart';
import 'package:featherpeakfurygame/domain/calc/peak_profile.dart';
import 'package:featherpeakfurygame/domain/calc/trip_analysis.dart';
import 'package:featherpeakfurygame/domain/models/hiker_profile.dart';
import 'package:featherpeakfurygame/domain/models/trip.dart';

const _profile = HikerProfile(bodyWeightKg: 70);

Trip _trip({
  double? distanceKm,
  double? elevationGainM,
  int? movingMinutes,
  Terrain? terrain,
  double? basePackKg,
  double? waterLitres,
  int people = 1,
  Intensity intensity = Intensity.moderate,
  List<GearItem> gear = const [],
  List<Expense> expenses = const [],
  String id = 'test-trip',
}) {
  final now = DateTime(2026, 8, 24);
  return Trip(
    id: id,
    name: 'Test',
    createdAt: now,
    updatedAt: now,
    distanceKm: distanceKm,
    elevationGainM: elevationGainM,
    movingMinutes: movingMinutes,
    terrain: terrain,
    basePackKg: basePackKg,
    waterLitres: waterLitres,
    people: people,
    intensity: intensity,
    gear: gear,
    expenses: expenses,
  );
}

void main() {
  group('difficulty', () {
    test('an empty trip scores nothing and reports zero confidence', () {
      final result = DifficultyResult.of(_trip(), _profile);
      expect(result.score, 0);
      expect(result.confidence, 0);
      expect(result.missingFactors.length, DifficultyFactor.values.length);
    });

    test('a maxed-out trip reaches the top of the scale', () {
      final result = DifficultyResult.of(
        _trip(
          distanceKm: 40,
          elevationGainM: 2500,
          movingMinutes: 700,
          terrain: Terrain.snow,
          basePackKg: 30,
        ),
        _profile,
      );
      expect(result.score, 100);
      expect(result.tier, DifficultyTier.veryHard);
      expect(result.isComplete, isTrue);
    });

    test('one extreme factor alone cannot reach the top tier', () {
      // Everything is trivial except a punishing amount of climbing.
      final result = DifficultyResult.of(
        _trip(
          distanceKm: 1,
          elevationGainM: 4000,
          movingMinutes: 30,
          terrain: Terrain.grass,
          basePackKg: 1,
        ),
        _profile,
      );
      expect(result.score, lessThan(DifficultyTier.veryHard.from));
    });

    test('confidence tracks the weight of the factors provided', () {
      final result = DifficultyResult.of(
        _trip(distanceKm: 10, movingMinutes: 240),
        _profile,
      );
      expect(
        result.confidence,
        closeTo(
          DifficultyFactor.distance.weight + DifficultyFactor.duration.weight,
          1e-9,
        ),
      );
      expect(result.isComplete, isFalse);
    });

    test('the same pack is judged against the hiker, not a fixed number', () {
      final trip = _trip(basePackKg: 14);
      final light = DifficultyResult.of(
        trip,
        const HikerProfile(bodyWeightKg: 50),
      );
      final heavy = DifficultyResult.of(
        trip,
        const HikerProfile(bodyWeightKg: 100),
      );
      expect(light.score, greaterThan(heavy.score));
    });
  });

  group('load', () {
    test('water is counted at a kilogram per litre', () {
      final result = LoadResult.of(
        _trip(basePackKg: 5, waterLitres: 2),
        _profile,
      );
      expect(result.totalKg, 7);
      expect(
        result.portions.firstWhere((p) => p.slice == LoadSlice.water).weightKg,
        2,
      );
    });

    test('gear quantity multiplies into the total', () {
      final result = LoadResult.of(
        _trip(
          gear: const [
            GearItem(
              id: 'a',
              name: 'Energy bar',
              category: GearCategory.food,
              weightKg: 0.05,
              quantity: 10,
            ),
          ],
        ),
        _profile,
      );
      expect(result.totalKg, closeTo(0.5, 1e-9));
    });

    test('thresholds follow body weight', () {
      final result = LoadResult.of(_trip(basePackKg: 15), _profile);
      expect(result.recommendedMaxKg, closeTo(14, 1e-9));
      expect(result.isOverRecommended, isTrue);
      expect(result.isHeavy, isFalse);
      expect(result.bodySharePercent, closeTo(21.43, 0.01));
    });

    test('a dominant category is only flagged once something is itemised', () {
      final packOnly = LoadResult.of(_trip(basePackKg: 12), _profile);
      expect(packOnly.dominantPortion, isNull);

      final itemised = LoadResult.of(
        _trip(
          basePackKg: 1,
          gear: const [
            GearItem(
              id: 'a',
              name: 'Tent',
              category: GearCategory.equipment,
              weightKg: 9,
            ),
          ],
        ),
        _profile,
      );
      expect(itemised.dominantPortion?.slice, LoadSlice.equipment);
    });
  });

  group('food', () {
    test('no moving time means no estimate rather than a guess', () {
      expect(FoodEstimate.of(_trip()), isNull);
    });

    test('a short outing still gets one unit per person', () {
      final result = FoodEstimate.of(_trip(movingMinutes: 45, people: 2))!;
      expect(result.baseUnits, 2);
      expect(result.reserveUnits, 0);
      expect(result.totalUnits, 2);
    });

    test('long days add a reserve unit per person', () {
      final result = FoodEstimate.of(_trip(movingMinutes: 480, people: 2))!;
      expect(result.baseUnits, 4);
      expect(result.reserveUnits, 2);
      expect(result.totalUnits, 6);
    });

    test('intensity raises the recommendation', () {
      final moderate = FoodEstimate.of(_trip(movingMinutes: 480))!;
      final hard = FoodEstimate.of(
        _trip(movingMinutes: 480, intensity: Intensity.veryHigh),
      )!;
      expect(hard.totalUnits, greaterThan(moderate.totalUnits));
    });
  });

  group('moving time estimate', () {
    test('needs a distance before it speaks', () {
      expect(MovingTimeEstimate.of(_trip(elevationGainM: 800)), isNull);
      expect(MovingTimeEstimate.of(_trip(distanceKm: 0)), isNull);
    });

    test('distance alone is 5 km per hour', () {
      final result = MovingTimeEstimate.of(_trip(distanceKm: 10))!;
      expect(result.minutes, 120);
      expect(result.includesClimb, isFalse);
    });

    test('climb adds one hour per 600 m', () {
      final result = MovingTimeEstimate.of(
        _trip(distanceKm: 10, elevationGainM: 600),
      )!;
      expect(result.minutes, 180);
      expect(result.includesClimb, isTrue);
    });

    test('a plan well under the baseline is optimistic', () {
      final result = MovingTimeEstimate.of(
        _trip(distanceKm: 10, elevationGainM: 600),
      )!;
      expect(result.isOptimistic(120), isTrue);
      expect(result.isOptimistic(180), isFalse);
      expect(result.isOptimistic(null), isFalse);
    });
  });

  group('budget', () {
    test('an empty budget stays empty', () {
      final result = BudgetResult.of(_trip());
      expect(result.isEmpty, isTrue);
      expect(result.total, 0);
    });

    test('totals split per person and per category', () {
      final result = BudgetResult.of(
        _trip(
          people: 2,
          expenses: const [
            Expense(
              id: 'a',
              label: 'Fuel',
              category: ExpenseCategory.transport,
              amount: 60,
            ),
            Expense(
              id: 'b',
              label: 'Parking',
              category: ExpenseCategory.parking,
              amount: 20,
            ),
          ],
        ),
      );
      expect(result.total, 80);
      expect(result.perPerson, 40);
      expect(result.largest?.category, ExpenseCategory.transport);
      expect(result.largest?.share, closeTo(0.75, 1e-9));
    });
  });

  group('peak profile', () {
    test('needs a distance to lay the route out along', () {
      expect(PeakProfileResult.of(_trip(elevationGainM: 500)), isNull);
    });

    test('segment distances add up to the route distance', () {
      final result = PeakProfileResult.of(
        _trip(distanceKm: 12, elevationGainM: 800),
      )!;
      expect(
        result.uphillKm + result.downhillKm + result.flatKm,
        closeTo(12, 0.01),
      );
      expect(result.hardKm, lessThanOrEqualTo(result.uphillKm + 1e-9));
    });

    test('the same trip always produces the same curve', () {
      final trip = _trip(distanceKm: 12, elevationGainM: 800);
      final first = PeakProfileResult.of(trip)!;
      final second = PeakProfileResult.of(trip)!;
      expect(first.peakElevationM, second.peakElevationM);
      expect(first.uphillKm, second.uphillKm);
    });

    test('a flat baseline is marked as estimated', () {
      final result = PeakProfileResult.of(_trip(distanceKm: 8))!;
      expect(result.isEstimated, isTrue);
      expect(result.peakElevationM, 0);
    });
  });

  group('fury zones', () {
    FuryResult run(Trip trip, [HikerProfile profile = _profile]) {
      final difficulty = DifficultyResult.of(trip, profile);
      final load = LoadResult.of(trip, profile);
      return FuryResult.of(
        trip,
        profile,
        difficulty,
        load,
        FoodEstimate.of(trip),
      );
    }

    test('a modest, well-provisioned day raises nothing serious', () {
      final result = run(
        _trip(
          distanceKm: 8,
          elevationGainM: 300,
          movingMinutes: 180,
          terrain: Terrain.grass,
          basePackKg: 4,
          waterLitres: 1.5,
          gear: const [
            GearItem(
              id: 'a',
              name: 'Lunch',
              category: GearCategory.food,
              weightKg: 0.5,
            ),
          ],
        ),
      );
      expect(result.seriousCount, 0);
      expect(result.level, isIn([FuryLevel.clear, FuryLevel.watch]));
    });

    test('a steep, heavy, long day escalates to the top level', () {
      final result = run(
        _trip(
          distanceKm: 14,
          elevationGainM: 1800,
          movingMinutes: 660,
          terrain: Terrain.snow,
          basePackKg: 22,
          waterLitres: 0.5,
        ),
      );
      expect(result.level, FuryLevel.high);
      expect(result.highCount, greaterThanOrEqualTo(2));
      // Highest severity first, so the list reads top-down by importance.
      expect(result.findings.first.severity, FurySeverity.high);
    });

    test('missing water is a notice, not a warning', () {
      final result = run(_trip(distanceKm: 6, movingMinutes: 120));
      final water = result.findings.firstWhere(
        (f) => f.title == 'Water not planned',
      );
      expect(water.severity, FurySeverity.notice);
    });
  });

  group('trip analysis', () {
    test('missing inputs are listed with what they affect', () {
      final analysis = TripAnalysis.of(_trip(), _profile);
      expect(analysis.missing.length, MissingInput.values.length);
      expect(analysis.isComplete, isFalse);
      expect(analysis.completeness, 0);
    });

    test('a fully specified trip reports complete', () {
      final analysis = TripAnalysis.of(
        _trip(
          distanceKm: 10,
          elevationGainM: 600,
          movingMinutes: 300,
          terrain: Terrain.rock,
          basePackKg: 8,
          waterLitres: 2,
          expenses: const [
            Expense(
              id: 'a',
              label: 'Fuel',
              category: ExpenseCategory.transport,
              amount: 30,
            ),
          ],
        ),
        _profile,
      );
      expect(analysis.missing, isEmpty);
      expect(analysis.isComplete, isTrue);
      expect(analysis.completeness, 1);
    });
  });

  group('serialisation', () {
    test('a trip survives a round trip through JSON', () {
      final original = _trip(
        distanceKm: 12.5,
        elevationGainM: 850,
        movingMinutes: 330,
        terrain: Terrain.rock,
        basePackKg: 7.5,
        waterLitres: 2,
        people: 3,
        intensity: Intensity.high,
        gear: const [
          GearItem(
            id: 'g1',
            name: 'Stove',
            category: GearCategory.equipment,
            weightKg: 0.4,
            quantity: 2,
          ),
        ],
        expenses: const [
          Expense(
            id: 'e1',
            label: 'Permit',
            category: ExpenseCategory.other,
            amount: 12.5,
          ),
        ],
      );

      final restored = Trip.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.distanceKm, original.distanceKm);
      expect(restored.terrain, original.terrain);
      expect(restored.intensity, original.intensity);
      expect(restored.people, original.people);
      expect(restored.gear.single.totalKg, closeTo(0.8, 1e-9));
      expect(restored.expenses.single.amount, 12.5);
      expect(restored.totalLoadKg, original.totalLoadKg);
    });
  });
}
