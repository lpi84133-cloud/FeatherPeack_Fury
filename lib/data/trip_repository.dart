import '../core/storage/fp_storage.dart';
import '../domain/models/trip.dart';

class TripRepository {
  const TripRepository();

  /// Newest first, which is the order every list in the app wants.
  List<Trip> loadAll() {
    final trips = <Trip>[];
    for (final raw in FpStorage.trips.values) {
      if (raw is Map) {
        try {
          trips.add(Trip.fromJson(raw));
        } on Object {
          // A record written by an older, incompatible schema is skipped rather
          // than crashing the archive.
        }
      }
    }
    trips.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return trips;
  }

  Future<void> save(Trip trip) =>
      FpStorage.trips.put(trip.id, trip.toJson());

  Future<void> delete(String id) => FpStorage.trips.delete(id);

  Future<void> deleteAll() => FpStorage.trips.clear();

  String? lastOpenedId() =>
      FpStorage.prefs.get(FpStorage.lastOpenedTripKey) as String?;

  Future<void> setLastOpenedId(String? id) => id == null
      ? FpStorage.prefs.delete(FpStorage.lastOpenedTripKey)
      : FpStorage.prefs.put(FpStorage.lastOpenedTripKey, id);
}
