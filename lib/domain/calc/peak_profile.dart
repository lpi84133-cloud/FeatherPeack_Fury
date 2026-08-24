import 'dart:math' as math;

import '../models/trip.dart';

enum SegmentKind {
  uphill('Uphill'),
  downhill('Downhill'),
  flat('Flat'),
  hard('Hard section');

  const SegmentKind(this.label);

  final String label;
}

class ProfilePoint {
  const ProfilePoint({
    required this.distanceKm,
    required this.elevationM,
    required this.kind,
  });

  final double distanceKm;
  final double elevationM;
  final SegmentKind kind;
}

/// A readable shape for the numbers the user typed in — not survey data. The
/// curve is derived deterministically from the trip id, so the same trip always
/// renders the same profile instead of reshuffling on every open.
class PeakProfileResult {
  const PeakProfileResult({
    required this.points,
    required this.uphillKm,
    required this.downhillKm,
    required this.flatKm,
    required this.hardKm,
    required this.peakElevationM,
    required this.steepestGradePercent,
    required this.isEstimated,
  });

  final List<ProfilePoint> points;
  final double uphillKm;
  final double downhillKm;
  final double flatKm;
  final double hardKm;
  final double peakElevationM;
  final double steepestGradePercent;

  /// True whenever elevation was not supplied and the curve is a flat baseline.
  final bool isEstimated;

  static const _samples = 41;
  static const _uphillThresholdMPerKm = 25.0;
  static const _hardThresholdMPerKm = 110.0;

  static PeakProfileResult? of(Trip trip) {
    final distance = trip.distanceKm;
    if (distance == null || distance <= 0) return null;

    final gain = trip.elevationGainM ?? 0;
    final random = math.Random(trip.id.hashCode);
    final summitAt = 0.5 + (random.nextDouble() - 0.5) * 0.24;
    final phaseA = random.nextDouble() * math.pi * 2;
    final phaseB = random.nextDouble() * math.pi * 2;

    // Terrain roughness shows up as more undulation along the way.
    final roughness = switch (trip.terrain) {
      Terrain.rock => 0.085,
      Terrain.snow => 0.07,
      Terrain.sand => 0.055,
      Terrain.grass => 0.04,
      null => 0.05,
    };

    double smoothstep(double t) {
      final x = t.clamp(0.0, 1.0);
      return x * x * (3 - 2 * x);
    }

    double shape(double x) {
      final climb = x <= summitAt
          ? smoothstep(x / summitAt)
          : 1 - 0.85 * smoothstep((x - summitAt) / (1 - summitAt));
      final undulation =
          roughness * math.sin(2 * math.pi * 3.3 * x + phaseA) +
          roughness * 0.6 * math.sin(2 * math.pi * 7.1 * x + phaseB);
      return (climb + undulation).clamp(0.0, 1.08);
    }

    final elevations = <double>[];
    for (var i = 0; i < _samples; i++) {
      elevations.add(shape(i / (_samples - 1)) * gain);
    }

    final step = distance / (_samples - 1);
    var uphill = 0.0;
    var downhill = 0.0;
    var flat = 0.0;
    var hard = 0.0;
    var steepestGrade = 0.0;
    final kinds = <SegmentKind>[SegmentKind.flat];

    for (var i = 1; i < _samples; i++) {
      final delta = elevations[i] - elevations[i - 1];
      final slope = delta / step; // metres per kilometre
      final grade = (delta / (step * 1000)) * 100;
      steepestGrade = math.max(steepestGrade, grade);

      final SegmentKind kind;
      if (slope >= _hardThresholdMPerKm) {
        kind = SegmentKind.hard;
        hard += step;
        uphill += step;
      } else if (slope >= _uphillThresholdMPerKm) {
        kind = SegmentKind.uphill;
        uphill += step;
      } else if (slope <= -_uphillThresholdMPerKm) {
        kind = SegmentKind.downhill;
        downhill += step;
      } else {
        kind = SegmentKind.flat;
        flat += step;
      }
      kinds.add(kind);
    }
    kinds[0] = kinds.length > 1 ? kinds[1] : SegmentKind.flat;

    return PeakProfileResult(
      points: [
        for (var i = 0; i < _samples; i++)
          ProfilePoint(
            distanceKm: step * i,
            elevationM: elevations[i],
            kind: kinds[i],
          ),
      ],
      uphillKm: uphill,
      downhillKm: downhill,
      flatKm: flat,
      hardKm: hard,
      peakElevationM: elevations.reduce(math.max),
      steepestGradePercent: steepestGrade,
      isEstimated: trip.elevationGainM == null,
    );
  }
}
