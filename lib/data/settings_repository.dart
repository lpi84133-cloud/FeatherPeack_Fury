import '../core/storage/fp_storage.dart';
import '../domain/models/app_settings.dart';

class SettingsRepository {
  const SettingsRepository();

  AppSettings load() {
    final raw = FpStorage.prefs.get(FpStorage.settingsKey);
    if (raw is Map) {
      try {
        return AppSettings.fromJson(raw);
      } on Object {
        return const AppSettings();
      }
    }
    return const AppSettings();
  }

  Future<void> save(AppSettings settings) =>
      FpStorage.prefs.put(FpStorage.settingsKey, settings.toJson());
}
