import '../../core/design/fp_images.dart';
import '../models/hiker_profile.dart';
import '../models/trip.dart';
import 'difficulty.dart';
import 'food_estimate.dart';
import 'load_breakdown.dart';

enum FurySeverity {
  notice('Notice', 0),
  attention('Attention', 1),
  high('High', 2);

  const FurySeverity(this.label, this.rank);

  final String label;
  final int rank;
}

/// Overall temperature of the plan. Kept deliberately coarse so warnings do not
/// lose meaning by firing on every trip.
enum FuryLevel {
  clear('Clear', 'Nothing stands out in this plan.'),
  watch('Worth a look', 'One parameter is worth checking before you go.'),
  attention('Needs attention', 'Several parameters combine into real effort.'),
  high('Demanding plan', 'Multiple demanding factors stack up on this route.');

  const FuryLevel(this.label, this.summary);

  final String label;
  final String summary;
}

class FuryFinding {
  const FuryFinding({
    required this.title,
    required this.detail,
    required this.severity,
    required this.image,
  });

  final String title;
  final String detail;
  final FurySeverity severity;
  final String image;
}

/// Fury Zones never block a plan. They point at the parameters that deserve a
/// second look while there is still time to prepare.
class FuryResult {
  const FuryResult({required this.findings, required this.level});

  final List<FuryFinding> findings;
  final FuryLevel level;

  int get seriousCount =>
      findings.where((f) => f.severity.rank >= FurySeverity.attention.rank).length;

  int get highCount =>
      findings.where((f) => f.severity == FurySeverity.high).length;

  static const steepGradeAttention = 80.0; // metres of gain per kilometre
  static const steepGradeHigh = 120.0;
  static const longDayHours = 8.0;
  static const veryLongDayHours = 10.0;
  static const waterPerPersonPerHourLitres = 0.4;

  static FuryResult of(
    Trip trip,
    HikerProfile profile,
    DifficultyResult difficulty,
    LoadResult load,
    FoodEstimate? food,
  ) {
    final findings = <FuryFinding>[];

    final distance = trip.distanceKm;
    final gain = trip.elevationGainM;
    if (distance != null && distance > 0 && gain != null && gain > 0) {
      final perKm = gain / distance;
      if (perKm >= steepGradeAttention) {
        findings.add(
          FuryFinding(
            title: 'Steep climb',
            detail:
                '${gain.round()} m of gain packed into '
                '${distance.toStringAsFixed(1)} km — about '
                '${perKm.round()} m per kilometre.',
            severity: perKm >= steepGradeHigh
                ? FurySeverity.high
                : FurySeverity.attention,
            image: FpImages.furySteepSign,
          ),
        );
      }
    }

    if (gain != null && gain >= 1000) {
      findings.add(
        FuryFinding(
          title: 'Large elevation gain',
          detail:
              '${gain.round()} m of total climbing. Plan the pace and the '
              'turnaround time before you start.',
          severity: gain >= 1500 ? FurySeverity.high : FurySeverity.attention,
          image: FpImages.peakSnow,
        ),
      );
    }

    if (load.totalKg > 0 && load.isOverRecommended) {
      findings.add(
        FuryFinding(
          title: 'Heavy load',
          detail:
              '${load.totalKg.toStringAsFixed(1)} kg is '
              '${load.bodySharePercent.round()}% of your body weight. '
              'Comfortable range is up to '
              '${load.recommendedMaxKg.toStringAsFixed(1)} kg.',
          severity: load.isHeavy ? FurySeverity.high : FurySeverity.attention,
          image: FpImages.furyHeavyPack,
        ),
      );
    }

    final hours = trip.movingHours;
    if (hours != null && hours >= longDayHours) {
      findings.add(
        FuryFinding(
          title: 'Long day',
          detail:
              '${hours.toStringAsFixed(1)} hours of moving time. Daylight, '
              'food and water all become limiting factors.',
          severity: hours >= veryLongDayHours
              ? FurySeverity.high
              : FurySeverity.attention,
          image: FpImages.furyLongDuration,
        ),
      );
    }

    switch (trip.terrain) {
      case Terrain.snow:
        findings.add(
          const FuryFinding(
            title: 'Snow and ice',
            detail:
                'Snow slows the pace and demands traction. Expect the moving '
                'time to run longer than on a dry path.',
            severity: FurySeverity.attention,
            image: FpImages.weatherSnow,
          ),
        );
      case Terrain.rock:
        findings.add(
          const FuryFinding(
            title: 'Rocky ground',
            detail:
                'Technical footing costs time and energy, especially late in '
                'the day when attention drops.',
            severity: FurySeverity.notice,
            image: FpImages.furyRockySign,
          ),
        );
      case Terrain.sand:
      case Terrain.grass:
      case null:
        break;
    }

    final dominant = load.dominantPortion;
    if (dominant != null) {
      findings.add(
        FuryFinding(
          title: 'Unbalanced pack',
          detail:
              '${dominant.slice.label} alone is '
              '${(dominant.share * 100).round()}% of the load '
              '(${dominant.weightKg.toStringAsFixed(1)} kg). Worth checking '
              'whether all of it needs to come along.',
          severity: FurySeverity.notice,
          image: FpImages.featherBrown,
        ),
      );
    }

    if (hours != null && hours > 0) {
      final water = trip.waterLitres;
      if (water == null || water == 0) {
        findings.add(
          const FuryFinding(
            title: 'Water not planned',
            detail:
                'No water volume entered yet, so the load and the hydration '
                'check are both incomplete.',
            severity: FurySeverity.notice,
            image: FpImages.gearBottle,
          ),
        );
      } else {
        final needed = waterPerPersonPerHourLitres * hours * trip.people;
        if (water < needed) {
          findings.add(
            FuryFinding(
              title: 'Low water volume',
              detail:
                  '${water.toStringAsFixed(1)} L for ${trip.people} '
                  '${trip.people == 1 ? 'person' : 'people'} over '
                  '${hours.toStringAsFixed(1)} h. A common planning figure is '
                  'around ${needed.toStringAsFixed(1)} L.',
              severity: FurySeverity.attention,
              image: FpImages.gearBottle,
            ),
          );
        }
      }
    }

    if (food != null) {
      final carried = trip.gear
          .where((item) => item.category == GearCategory.food)
          .fold<double>(0, (sum, item) => sum + item.totalKg);
      if (carried == 0) {
        findings.add(
          FuryFinding(
            title: 'Food not itemised',
            detail:
                'EggPack recommends ${food.totalUnits} '
                '${food.totalUnits == 1 ? 'unit' : 'units'}, but no food weight '
                'is listed in the pack yet.',
            severity: FurySeverity.notice,
            image: FpImages.eggSingle,
          ),
        );
      } else if (carried < food.approxWeightKg * 0.6) {
        findings.add(
          FuryFinding(
            title: 'Food below the estimate',
            detail:
                '${carried.toStringAsFixed(1)} kg packed against roughly '
                '${food.approxWeightKg.toStringAsFixed(1)} kg for '
                '${food.totalUnits} recommended units.',
            severity: FurySeverity.attention,
            image: FpImages.eggPair,
          ),
        );
      }
    }

    if (trip.people == 1 &&
        difficulty.tier.index >= DifficultyTier.hard.index &&
        difficulty.confidence > 0.5) {
      findings.add(
        FuryFinding(
          title: 'Solo on a demanding route',
          detail:
              'Difficulty scores ${difficulty.score}/100 with one person in '
              'the group. Leaving your route and return time with someone is '
              'worth the minute it takes.',
          severity: FurySeverity.notice,
          image: FpImages.chickenPacked,
        ),
      );
    }

    findings.sort((a, b) => b.severity.rank.compareTo(a.severity.rank));

    final serious = findings
        .where((f) => f.severity.rank >= FurySeverity.attention.rank)
        .length;
    final level = switch (serious) {
      0 => findings.isEmpty ? FuryLevel.clear : FuryLevel.watch,
      1 => FuryLevel.watch,
      2 => FuryLevel.attention,
      _ => FuryLevel.high,
    };

    return FuryResult(findings: findings, level: level);
  }
}
