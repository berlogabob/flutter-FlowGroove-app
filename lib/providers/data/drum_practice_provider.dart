import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/midi_pattern.dart';
import '../../services/audio/midi/drum_map.dart';
import '../../services/audio/midi/drum_player.dart';
import 'metronome_provider.dart';

const Object _notSet = Object();

class DrumPracticeState {
  const DrumPracticeState({
    this.pattern,
    this.entryId,
    this.muted = const {},
    this.solo,
    this.playing = false,
    this.currentStep = 0,
    this.speed = 1,
  });

  final MidiPattern? pattern;
  final String? entryId;
  final Set<DrumLane> muted;
  final DrumLane? solo;
  final bool playing;
  final int currentStep;
  final double speed;

  DrumPracticeState copyWith({
    MidiPattern? pattern,
    String? entryId,
    Set<DrumLane>? muted,
    Object? solo = _notSet,
    bool? playing,
    int? currentStep,
    double? speed,
  }) {
    return DrumPracticeState(
      pattern: pattern ?? this.pattern,
      entryId: entryId ?? this.entryId,
      muted: muted == null ? this.muted : Set.unmodifiable(muted),
      solo: solo == _notSet ? this.solo : solo as DrumLane?,
      playing: playing ?? this.playing,
      currentStep: currentStep ?? this.currentStep,
      speed: speed ?? this.speed,
    );
  }
}

final drumPlayerProvider = Provider<DrumPlayer>((ref) => createDrumPlayer());

class DrumPracticeNotifier extends Notifier<DrumPracticeState> {
  late DrumPlayer _player;
  int _operationId = 0;
  bool _disposed = false;

  @override
  DrumPracticeState build() {
    _player = ref.read(drumPlayerProvider);
    final subscription = _player.stepStream.listen((step) {
      if (!_disposed && state.playing) {
        state = state.copyWith(currentStep: step);
      }
    });
    ref.listen<int>(metronomeProvider.select((value) => value.bpm), (_, _) {
      if (state.playing) unawaited(_reload());
    });
    ref.onDispose(() {
      _disposed = true;
      ++_operationId;
      unawaited(subscription.cancel());
      unawaited(_player.dispose());
    });
    return const DrumPracticeState();
  }

  Future<void> loadPattern(String entryId, MidiPattern pattern) {
    state = state.copyWith(entryId: entryId, pattern: pattern, currentStep: 0);
    return _reload();
  }

  void toggleMute(DrumLane lane) {
    final muted = {...state.muted};
    if (!muted.remove(lane)) muted.add(lane);
    state = state.copyWith(muted: muted);
    _syncGains();
  }

  void toggleSolo(DrumLane lane) {
    state = state.copyWith(solo: state.solo == lane ? null : lane);
    _syncGains();
  }

  Future<void> start() async {
    if (state.playing || state.pattern == null) return;
    state = state.copyWith(playing: true, currentStep: 0);
    await _reload();
  }

  Future<void> stop() async {
    ++_operationId;
    state = state.copyWith(playing: false, currentStep: 0);
    await _player.stop();
  }

  Future<void> setSpeed(double speed) async {
    if (!speed.isFinite || speed <= 0) {
      throw ArgumentError.value(speed, 'speed', 'Must be finite and positive');
    }
    if (state.speed == speed) return;
    state = state.copyWith(speed: speed);
    if (state.playing) await _reload();
  }

  void _syncGains() {
    for (final lane in DrumLane.values) {
      final audible = state.solo != null
          ? state.solo == lane
          : !state.muted.contains(lane);
      _player.setLaneGain(lane, audible ? 1 : 0);
    }
  }

  Future<void> _reload() async {
    final pattern = state.pattern;
    if (pattern == null) return;
    final operationId = ++_operationId;
    final bpm = ref.read(metronomeProvider).bpm * state.speed;
    try {
      _syncGains();
      await _player.load(pattern, bpm);
      // A stop or newer load must not be undone by an older async load.
      if (_disposed || operationId != _operationId) return;
      if (state.playing) await _player.start();
    } catch (error) {
      if (_disposed || operationId != _operationId) return;
      await stop();
      debugPrint('[DrumPracticeNotifier] Playback failed: $error');
    }
  }
}

final drumPracticeProvider =
    NotifierProvider<DrumPracticeNotifier, DrumPracticeState>(
      DrumPracticeNotifier.new,
    );
