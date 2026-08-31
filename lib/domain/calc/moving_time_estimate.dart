import '../models/trip.dart';

/// Naismith's rule: typical moving time from the route numbers the user already
/// entered. Distance at 5 km/h plus one hour per 600 m of climb. Terrain and
/// rest are left out on purpose so the figure stays a baseline, not a warning.
class MovingTimeEstimate {
  const MovingTimeEstimate({
    required this.minutes,
    required this.distanceHours,
    required this.climbHours,
  });

  final int minutes;
  final double distanceHours;
  final double climbHours;

  static const kmPerHour = 5.0;
  static const climbMetresPerHour = 600.0;

  /// Entered time within this share of the estimate is treated as in range.
  static const inRangeShare = 0.85;

  double get hours => minutes / 60.0;

  bool get includesClimb => climbHours > 0;

  /// True when the plan is noticeably shorter than the baseline.
  bool isOptimistic(int? movingMinutes) {
    if (movingMinutes == null || movingMinutes <= 0) return false;
    return movingMinutes < minutes * inRangeShare;
  }

  static MovingTimeEstimate? of(Trip trip) {
    final km = trip.distanceKm;
    if (km == null || km <= 0) return null;

    final distanceHours = km / kmPerHour;
    final climb = trip.elevationGainM ?? 0;
    final climbHours = climb <= 0 ? 0.0 : climb / climbMetresPerHour;
    final minutes = ((distanceHours + climbHours) * 60).round().clamp(1, 24 * 60);

    return MovingTimeEstimate(
      minutes: minutes,
      distanceHours: distanceHours,
      climbHours: climbHours,
    );
  }
}
