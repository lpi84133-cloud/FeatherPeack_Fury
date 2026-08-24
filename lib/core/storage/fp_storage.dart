import 'dart:io';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// Local storage. Two plain boxes hold JSON maps, which keeps the schema easy
/// to migrate and avoids generated adapters entirely.
abstract final class FpStorage {
  static const _tripsBoxName = 'trips';
  static const _prefsBoxName = 'prefs';
  static const _subDirectory = 'featherpeak';

  static const settingsKey = 'settings';
  static const profileKey = 'profile';
  static const lastOpenedTripKey = 'lastOpenedTrip';

  static late Directory _documents;
  static late Box<dynamic> _trips;
  static late Box<dynamic> _prefs;

  static Box<dynamic> get trips => _trips;
  static Box<dynamic> get prefs => _prefs;
  static Directory get documents => _documents;

  static Future<void> init() async {
    _documents = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(_subDirectory);
  }

  static Future<void> openTrips() async {
    _trips = await Hive.openBox<dynamic>(_tripsBoxName);
  }

  static Future<void> openPrefs() async {
    _prefs = await Hive.openBox<dynamic>(_prefsBoxName);
  }

  /// Size of everything the app has written, used by Settings → Data & storage.
  static Future<int> usedBytes() async {
    var total = 0;
    final hiveDirectory = Directory('${_documents.path}/$_subDirectory');
    for (final directory in [hiveDirectory, _documents]) {
      if (!directory.existsSync()) continue;
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is File) total += await entity.length();
      }
    }
    return total;
  }

  static Future<void> clearAll() async {
    await _trips.clear();
    await _prefs.clear();
  }
}
