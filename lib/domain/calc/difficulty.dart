import 'dart:math' as math;

import '../models/hiker_profile.dart';
import '../models/trip.dart';

enum DifficultyTier {
  easy('Easy', 0, 25),
  moderate('Moderate', 26, 50),
  hard('Hard', 51, 75),
  veryHard('Very hard', 76, 100);

  const DifficultyTier(this.label, this.from, this.to);

  final String label;
  final int from;
  final int to;

  static DifficultyTier of(int score) {
    if (score <= 25) return easy;
    if (score <= 50) return moderate;
    if (score <= 75) return hard;
    return veryHard;
  }
}

enum DifficultyFactor {
  distance('Distance', 0.25),
  elevation('Elevation', 0.30),
  duration('Duration', 0.15),
  terrain('Terrain', 0.10),
  load('Load', 0.20);

  const DifficultyFactor(this.label, this.weight);

  final String label;
  final double weight;
}

class FactorScore {
  const FactorScore({
    required this.factor,
    required this.ratio,
    required this.known,
  });

  final DifficultyFactor factor;

  /// 0..1 position between "no effort" and the reference ceiling.
  final double ratio;
  final bool known;

  /// Points out of 100 that this factor contributes.
  int get points => (ratio * factor.weight * 100).round();

  int get maxPoints => (factor.weight * 100).round();
}

/// Weighted difficulty model. A single extreme value cannot push the trip to
/// the top tier on its own, because every factor is capped by its own weight.
class DifficultyResult {
  const DifficultyResult({
    required this.score,
    required this.tier,
    required this.factors,
    required this.confidence,
  });

  final int score;
  final DifficultyTier tier;
  final List<FactorScore> factors;

  /// Share of the model's weight that could actually be evaluated, 0..1.
  final double confidence;

  bool get isComplete => confidence >= 0.999;

  List<DifficultyFactor> get missingFactors =>
      factors.where((f) => !f.known).map((f) => f.factor).toList();

  static const referenceDistanceKm = 30.0;
  static const referenceElevationM = 2000.0;
  static const referenceMovingMinutes = 600.0;

  /// Load is measured against a share of body weight rather than a fixed number
  /// of kilograms, so the same pack is judged differently for different people.
  static const referenceLoadBodyShare = 0.30;

  static DifficultyResult of(Trip trip, HikerProfile profile) {
    double ratio(double value, double reference) =>
        (value / reference).clamp(0.0, 1.0);

    final scores = <FactorScore>[
      FactorScore(
        factor: DifficultyFactor.distance,
        ratio: trip.distanceKm == null
            ? 0
            : ratio(trip.distanceKm!, referenceDistanceKm),
        known: trip.distanceKm != null,
      ),
      FactorScore(
        factor: DifficultyFactor.elevation,
        ratio: trip.elevationGainM == null
            ? 0
            : ratio(trip.elevationGainM!, referenceElevationM),
        known: trip.elevationGainM != null,
      ),
      FactorScore(
        factor: DifficultyFactor.duration,
        ratio: trip.movingMinutes == null
            ? 0
            : ratio(trip.movingMinutes!.toDouble(), referenceMovingMinutes),
        known: trip.movingMinutes != null,
      ),
      FactorScore(
        factor: DifficultyFactor.terrain,
        ratio: trip.terrain?.factor ?? 0,
        known: trip.terrain != null,
      ),
      FactorScore(
        factor: DifficultyFactor.load,
        ratio: trip.hasLoadData
            ? ratio(
                trip.totalLoadKg,
                profile.bodyWeightKg * referenceLoadBodyShare,
              )
            : 0,
        known: trip.hasLoadData,
      ),
    ];

    final availableWeight = scores
        .where((s) => s.known)
        .fold<double>(0, (sum, s) => sum + s.factor.weight);

    final rawPoints = scores
        .where((s) => s.known)
        .fold<double>(0, (sum, s) => sum + s.ratio * s.factor.weight);

    // Scored against the factors we could evaluate, so a half-filled trip is
    // not silently reported as an easy one.
    final score = availableWeight == 0
        ? 0
        : (rawPoints / availableWeight * 100).round().clamp(0, 100);

    return DifficultyResult(
      score: score,
      tier: DifficultyTier.of(score),
      factors: scores,
      confidence: math.min(1.0, availableWeight),
    );
  }
}
