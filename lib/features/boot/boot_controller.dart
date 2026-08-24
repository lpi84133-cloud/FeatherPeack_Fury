import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/fp_feedback.dart';
import '../../core/design/fp_images.dart';
import '../../core/storage/fp_storage.dart';
import '../../data/providers.dart';

/// Each stage is a real piece of start-up work. The weights are proportional to
/// how long they actually take, so the bar advances at an even pace instead of
/// jumping between arbitrary checkpoints.
enum BootStage {
  storage('Opening local storage', 0.18),
  settings('Reading preferences', 0.06),
  profile('Loading your profile', 0.06),
  archive('Loading saved trips', 0.14),
  images('Preparing illustrations', 0.34),
  audio('Warming up interface sounds', 0.12),
  ready('Finishing up', 0.10);

  const BootStage(this.label, this.weight);

  final String label;
  final double weight;

  double get startOffset {
    var offset = 0.0;
    for (final stage in BootStage.values) {
      if (stage == this) break;
      offset += stage.weight;
    }
    return offset;
  }
}

@immutable
class BootState {
  const BootState({
    this.progress = 0,
    this.stage = BootStage.storage,
    this.isFinished = false,
    this.degraded = const [],
  });

  /// 0..1, and only ever 1.0 once every stage has actually finished.
  final double progress;
  final BootStage stage;
  final bool isFinished;

  /// Stages that failed but are not worth blocking the launch over.
  final List<String> degraded;

  BootState copyWith({
    double? progress,
    BootStage? stage,
    bool? isFinished,
    List<String>? degraded,
  }) {
    return BootState(
      progress: progress ?? this.progress,
      stage: stage ?? this.stage,
      isFinished: isFinished ?? this.isFinished,
      degraded: degraded ?? this.degraded,
    );
  }
}

class BootController extends Notifier<BootState> {
  /// Hard ceiling on the whole sequence. If anything hangs, the app opens with
  /// a note in Settings instead of sitting on the loading screen forever.
  static const watchdog = Duration(seconds: 8);
  static const _stageTimeout = Duration(seconds: 4);

  bool _started = false;
  final _degraded = <String>[];

  @override
  BootState build() => const BootState();

  /// Reports progress inside a stage. Values are clamped and never allowed to
  /// move backwards, because a bar that retreats reads as a freeze.
  void _report(BootStage stage, double fraction) {
    final target = stage.startOffset + stage.weight * fraction.clamp(0.0, 1.0);
    state = state.copyWith(
      stage: stage,
      progress: target > state.progress ? target : state.progress,
    );
  }

  Future<void> _run(BootStage stage, Future<void> Function() task) async {
    _report(stage, 0);
    try {
      await task().timeout(_stageTimeout);
    } on Object {
      _degraded.add(stage.label);
    }
    _report(stage, 1);
  }

  Future<void> start(BuildContext context) async {
    if (_started) return;
    _started = true;

    try {
      await _sequence(context).timeout(watchdog);
    } on TimeoutException {
      _degraded.add('Start-up took longer than expected');
    }

    state = state.copyWith(
      progress: 1,
      stage: BootStage.ready,
      isFinished: true,
      degraded: List.unmodifiable(_degraded),
    );
  }

  Future<void> _sequence(BuildContext context) async {
    await _run(BootStage.storage, () async {
      await FpStorage.init();
      await FpStorage.openPrefs();
      await FpStorage.openTrips();
    });

    await _run(BootStage.settings, () async {
      final settings = ref.read(settingsProvider);
      FpFeedback.instance
        ..soundEnabled = settings.soundEnabled
        ..hapticsEnabled = settings.hapticsEnabled;
    });

    await _run(BootStage.profile, () async {
      ref.read(profileProvider);
    });

    await _run(BootStage.archive, () async {
      ref.read(tripsProvider);
      ref.read(currentTripIdProvider);
    });

    // The slowest stage, so it reports after every single image rather than
    // once at the end.
    _report(BootStage.images, 0);
    final images = FpImages.precacheList;
    for (var i = 0; i < images.length; i++) {
      if (!context.mounted) break;
      try {
        await precacheImage(AssetImage(images[i]), context);
      } on Object {
        _degraded.add('Illustration ${images[i]}');
      }
      _report(BootStage.images, (i + 1) / images.length);
    }

    await _run(BootStage.audio, () async {
      await FpFeedback.instance.warmUp(
        onProgress: (fraction) => _report(BootStage.audio, fraction),
      );
    });

    // Final stage is genuine work the first screen depends on: the dashboard
    // reads this analysis, and the frame after it is the one the user sees.
    await _run(BootStage.ready, () async {
      ref.read(currentAnalysisProvider);
      ref.read(archiveStatsProvider);
      await SchedulerBinding.instance.endOfFrame;
    });
  }
}

final bootProvider = NotifierProvider<BootController, BootState>(
  BootController.new,
);
