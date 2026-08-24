import 'dart:io';
import 'dart:typed_data';

import '../core/storage/fp_storage.dart';
import '../domain/models/hiker_profile.dart';

class ProfileRepository {
  const ProfileRepository();

  static const _avatarPrefix = 'avatar_';

  HikerProfile load() {
    final raw = FpStorage.prefs.get(FpStorage.profileKey);
    if (raw is Map) {
      try {
        return HikerProfile.fromJson(raw);
      } on Object {
        return const HikerProfile();
      }
    }
    return const HikerProfile();
  }

  Future<void> save(HikerProfile profile) =>
      FpStorage.prefs.put(FpStorage.profileKey, profile.toJson());

  File? avatarFile(HikerProfile profile) {
    final name = profile.avatarFileName;
    if (name == null) return null;
    final file = File('${FpStorage.documents.path}/$name');
    return file.existsSync() ? file : null;
  }

  /// Avatars are written under a fresh name every time so the image cache never
  /// serves the previous photo from a stale path.
  Future<String> writeAvatar(Uint8List bytes) async {
    final name = '$_avatarPrefix${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File('${FpStorage.documents.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return name;
  }

  Future<void> deleteAvatars() async {
    final directory = FpStorage.documents;
    if (!directory.existsSync()) return;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File &&
          entity.uri.pathSegments.last.startsWith(_avatarPrefix)) {
        await entity.delete();
      }
    }
  }
}
