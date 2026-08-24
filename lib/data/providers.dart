import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/audio/fp_feedback.dart';
import '../core/utils/fp_format.dart';
import '../domain/calc/trip_analysis.dart';
import '../domain/models/app_settings.dart';
import '../domain/models/hiker_profile.dart';
import '../domain/models/trip.dart';
import 'profile_repository.dart';
import 'settings_repository.dart';
import 'trip_repository.dart';

const _uuid = Uuid();

final tripRepositoryProvider = Provider((ref) => const TripRepository());
final settingsRepositoryProvider = Provider(
  (ref) => const SettingsRepository(),
);
final profileRepositoryProvider = Provider((ref) => const ProfileRepository());

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(settingsRepositoryProvider).load();

  Future<void> _write(AppSettings next) async {
    state = next;
    FpFeedback.instance
      ..soundEnabled = next.soundEnabled
      ..hapticsEnabled = next.hapticsEnabled;
    await ref.read(settingsRepositoryProvider).save(next);
  }

  Future<void> setDistanceUnit(DistanceUnit value) =>
      _write(state.copyWith(distanceUnit: value));

  Future<void> setElevationUnit(ElevationUnit value) =>
      _write(state.copyWith(elevationUnit: value));

  Future<void> setWeightUnit(WeightUnit value) =>
      _write(state.copyWith(weightUnit: value));

  Future<void> setVolumeUnit(VolumeUnit value) =>
      _write(state.copyWith(volumeUnit: value));

  Future<void> setTimeFormat(TimeFormat value) =>
      _write(state.copyWith(timeFormat: value));

  Future<void> setCurrencySymbol(String value) =>
      _write(state.copyWith(currencySymbol: value));

  Future<void> setDefaultIntensity(Intensity value) =>
      _write(state.copyWith(defaultIntensity: value));

  Future<void> setSoundEnabled(bool value) =>
      _write(state.copyWith(soundEnabled: value));

  Future<void> setHapticsEnabled(bool value) =>
      _write(state.copyWith(hapticsEnabled: value));

  Future<void> setRemindersEnabled(bool value) =>
      _write(state.copyWith(remindersEnabled: value));

  Future<void> setReminderTime(int hour, int minute) =>
      _write(state.copyWith(reminderHour: hour, reminderMinute: minute));

  Future<void> completeOnboarding() =>
      _write(state.copyWith(onboardingSeen: true));

  Future<void> resetToDefaults() => _write(
    const AppSettings().copyWith(onboardingSeen: state.onboardingSeen),
  );
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

final formatProvider = Provider(
  (ref) => FpFormat(ref.watch(settingsProvider)),
);

class ProfileController extends Notifier<HikerProfile> {
  @override
  HikerProfile build() => ref.read(profileRepositoryProvider).load();

  Future<void> _write(HikerProfile next) async {
    state = next;
    await ref.read(profileRepositoryProvider).save(next);
  }

  Future<void> setName(String value) => _write(state.copyWith(name: value));

  Future<void> setHomeArea(String value) =>
      _write(state.copyWith(homeArea: value));

  Future<void> setBodyWeight(double kg) => _write(
    state.copyWith(
      bodyWeightKg: kg.clamp(
        HikerProfile.minBodyWeightKg,
        HikerProfile.maxBodyWeightKg,
      ),
    ),
  );

  Future<void> setAvatar(Uint8List bytes) async {
    final repository = ref.read(profileRepositoryProvider);
    await repository.deleteAvatars();
    final name = await repository.writeAvatar(bytes);
    await _write(state.copyWith(avatarFileName: name));
  }

  Future<void> removeAvatar() async {
    await ref.read(profileRepositoryProvider).deleteAvatars();
    await _write(state.copyWith(clearAvatar: true));
  }
}

final profileProvider = NotifierProvider<ProfileController, HikerProfile>(
  ProfileController.new,
);

class TripsController extends Notifier<List<Trip>> {
  @override
  List<Trip> build() => ref.read(tripRepositoryProvider).loadAll();

  TripRepository get _repository => ref.read(tripRepositoryProvider);

  Trip createDraft({required String name}) {
    final now = DateTime.now();
    return Trip(
      id: _uuid.v4(),
      name: name,
      createdAt: now,
      updatedAt: now,
      intensity: ref.read(settingsProvider).defaultIntensity,
    );
  }

  Future<void> save(Trip trip) async {
    final next = trip.copyWith(updatedAt: DateTime.now());
    await _repository.save(next);
    final index = state.indexWhere((t) => t.id == next.id);
    final updated = [...state];
    if (index == -1) {
      updated.insert(0, next);
    } else {
      updated[index] = next;
    }
    updated.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = updated;
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    state = state.where((trip) => trip.id != id).toList();
    if (_repository.lastOpenedId() == id) {
      await _repository.setLastOpenedId(null);
    }
  }

  Future<Trip> duplicate(Trip trip) async {
    final now = DateTime.now();
    final copy = Trip(
      id: _uuid.v4(),
      name: '${trip.name} copy',
      createdAt: now,
      updatedAt: now,
      plannedDate: trip.plannedDate,
      distanceKm: trip.distanceKm,
      elevationGainM: trip.elevationGainM,
      movingMinutes: trip.movingMinutes,
      terrain: trip.terrain,
      basePackKg: trip.basePackKg,
      waterLitres: trip.waterLitres,
      people: trip.people,
      intensity: trip.intensity,
      notes: trip.notes,
      gear: trip.gear,
      expenses: trip.expenses,
    );
    await save(copy);
    return copy;
  }

  Future<void> deleteAll() async {
    await _repository.deleteAll();
    await _repository.setLastOpenedId(null);
    state = const [];
  }

  Trip? byId(String? id) {
    if (id == null) return null;
    for (final trip in state) {
      if (trip.id == id) return trip;
    }
    return null;
  }
}

final tripsProvider = NotifierProvider<TripsController, List<Trip>>(
  TripsController.new,
);

/// The trip the workspace is currently pointed at. Restored from storage on
/// launch so reopening the app lands on the plan you were last working on.
class CurrentTripController extends Notifier<String?> {
  @override
  String? build() {
    final id = ref.read(tripRepositoryProvider).lastOpenedId();
    final exists = ref.read(tripsProvider).any((trip) => trip.id == id);
    return exists ? id : null;
  }

  Future<void> select(String? id) async {
    state = id;
    await ref.read(tripRepositoryProvider).setLastOpenedId(id);
  }
}

final currentTripIdProvider = NotifierProvider<CurrentTripController, String?>(
  CurrentTripController.new,
);

final currentTripProvider = Provider<Trip?>((ref) {
  final id = ref.watch(currentTripIdProvider);
  final trips = ref.watch(tripsProvider);
  for (final trip in trips) {
    if (trip.id == id) return trip;
  }
  return null;
});

/// Analysis is a pure function of a trip and the hiker profile, so it is derived
/// rather than stored. Auto-disposed because saving a trip produces a new
/// instance, and the entry keyed by the previous one is then dead weight.
final analysisProvider = Provider.autoDispose.family<TripAnalysis, Trip>(
  (ref, trip) => TripAnalysis.of(trip, ref.watch(profileProvider)),
);

final currentAnalysisProvider = Provider<TripAnalysis?>((ref) {
  final trip = ref.watch(currentTripProvider);
  return trip == null ? null : ref.watch(analysisProvider(trip));
});

/// Aggregates shown on the profile screen — real numbers from saved trips.
class ArchiveStats {
  const ArchiveStats({
    required this.tripCount,
    required this.totalDistanceKm,
    required this.totalElevationM,
    required this.averageDifficulty,
    required this.plannedAhead,
  });

  final int tripCount;
  final double totalDistanceKm;
  final double totalElevationM;
  final int averageDifficulty;
  final int plannedAhead;

  bool get isEmpty => tripCount == 0;
}

final archiveStatsProvider = Provider<ArchiveStats>((ref) {
  final trips = ref.watch(tripsProvider);
  final profile = ref.watch(profileProvider);
  final now = DateTime.now();

  var distance = 0.0;
  var elevation = 0.0;
  var scoreSum = 0;
  var scored = 0;
  var upcoming = 0;

  for (final trip in trips) {
    distance += trip.distanceKm ?? 0;
    elevation += trip.elevationGainM ?? 0;
    final analysis = TripAnalysis.of(trip, profile);
    if (analysis.difficulty.confidence > 0) {
      scoreSum += analysis.difficulty.score;
      scored++;
    }
    final planned = trip.plannedDate;
    if (planned != null && planned.isAfter(now)) upcoming++;
  }

  return ArchiveStats(
    tripCount: trips.length,
    totalDistanceKm: distance,
    totalElevationM: elevation,
    averageDifficulty: scored == 0 ? 0 : (scoreSum / scored).round(),
    plannedAhead: upcoming,
  );
});
