import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// The twelve interface sounds shipped with the app.
enum FpSound {
  buttonTap('button_tap.mp3'),
  menuOpen('menu_open.mp3'),
  menuClose('menu_close.mp3'),
  screenOpen('screen_open.mp3'),
  screenBack('screen_back.mp3'),
  addItem('add_item.mp3'),
  removeItem('remove_item.mp3'),
  saveTrip('save_trip.mp3'),
  calculationComplete('calculation_complete.mp3'),
  successfulAction('successful_action.mp3'),
  warning('warning.mp3'),
  error('error.mp3');

  const FpSound(this.fileName);

  final String fileName;

  String get asset => 'sounds/$fileName';
}

/// Short interface sounds and haptics, both switchable in Settings.
///
/// Playback is configured to mix with whatever the user is already listening to
/// and never takes over the audio session.
class FpFeedback {
  FpFeedback._();

  static final instance = FpFeedback._();

  final _players = <FpSound, AudioPlayer>{};
  bool _ready = false;
  bool soundEnabled = true;
  bool hapticsEnabled = true;

  bool get isReady => _ready;

  Future<void> warmUp({void Function(double progress)? onProgress}) async {
    await AudioPlayer.global.setAudioContext(
      AudioContext(
        // The ambient category already mixes with other audio and is silenced
        // by the ring switch, which is exactly right for interface cues.
        iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
          audioFocus: AndroidAudioFocus.none,
        ),
      ),
    );

    final sounds = FpSound.values;
    for (var i = 0; i < sounds.length; i++) {
      final sound = sounds[i];
      try {
        final player = AudioPlayer(playerId: sound.name)
          ..setReleaseMode(ReleaseMode.stop);
        await player.setSource(AssetSource(sound.asset));
        await player.setVolume(0.55);
        _players[sound] = player;
      } on Object {
        // A single unavailable sound must not hold up the launch; the app simply
        // stays quiet for that event.
      }
      onProgress?.call((i + 1) / sounds.length);
    }
    _ready = true;
  }

  Future<void> play(FpSound sound) async {
    if (!soundEnabled || !_ready) return;
    final player = _players[sound];
    if (player == null) return;
    try {
      await player.stop();
      await player.resume();
    } on Object {
      // Ignore transient playback failures — audio is never load-bearing here.
    }
  }

  void tap() {
    play(FpSound.buttonTap);
    if (hapticsEnabled) HapticFeedback.selectionClick();
  }

  void success(FpSound sound) {
    play(sound);
    if (hapticsEnabled) HapticFeedback.lightImpact();
  }

  void warn() {
    play(FpSound.warning);
    if (hapticsEnabled) HapticFeedback.mediumImpact();
  }

  Future<void> dispose() async {
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
    _ready = false;
  }
}
