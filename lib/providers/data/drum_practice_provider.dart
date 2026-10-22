import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/midi_pattern.dart';
import '../../services/audio/midi/drum_map.dart';
import '../../services/audio/midi/drum_player.dart';
import 'backing_transport_provider.dart';
import 'drum_active_provider.dart';
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
    this.syncWithClick = true,
  });

  final MidiPattern? pattern;
  final String? entryId;
  final Set<DrumLane> muted;
  final DrumLane? solo;
  final bool playing;
  final int currentStep;
  final double speed;
  final bool syncWithClick;

  DrumPracticeState copyWith({
    Object? pattern = _notSet,
    Object? entryId = _notSet,
    Set<DrumLane>? muted,
    Object? solo = _notSet,
    bool? playing,
    int? currentStep,
    double? speed,
    bool? syncWithClick,
  }) {
    return DrumPracticeState(
      pattern: pattern == _notSet ? this.pattern : pattern as MidiPattern?,
      entryId: entryId == _notSet ? this.entryId : entryId as String?,
      muted: muted == null ? this.muted : Set.unmodifiable(muted),
      solo: solo == _notSet ? this.solo : solo as DrumLane?,
      playing: playing ?? this.playing,
      currentStep: currentStep ?? this.currentStep,
      speed: speed ?? this.speed,
      syncWithClick: syncWithClick ?? this.syncWithClick,
    );
  }
}

final drumPlayerProvider = Provider<DrumPlayer>((ref) {
  if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) {
    return _BackingDrumPlayer(ref);
  }
  return createDrumPlayer();
});

class _BackingDrumPlayer implements DrumPlayer {
  _BackingDrumPlayer(this.ref);

  final Ref ref;
  final _clock = DrumStepClock();
  final _gains = <DrumLane, double>{};
  MidiPattern? _pattern;
  double _bpm = 120;
  int _operationId = 0;

  @override
  bool get playing => _clock.playing;

  @override
  Stream<int> get stepStream => _clock.stream;

  @override
  Future<void> load(MidiPattern pattern, double bpm) async {
    drumStepIndex(Duration.zero, bpm, pattern.stepsPerBeat, pattern.totalSteps);
    ++_operationId;
    _clock.stop();
    _pattern = pattern;
    _bpm = bpm;
    await ref
        .read(backingTransportProvider.notifier)
        .attachPattern(
          MidiPattern(
            name: pattern.name,
            bars: pattern.bars,
            beatsPerBar: pattern.beatsPerBar,
            stepsPerBeat: pattern.stepsPerBeat,
            hits: pattern.hits.where((hit) {
              final lane = laneForNote(hit.note);
              return lane != null && (_gains[lane] ?? 1) > 0;
            }).toList(),
          ),
          bpm,
        );
  }

  @override
  Future<void> start() async {
    final operationId = _operationId;
    await ref.read(backingTransportProvider.notifier).launch('drum-pattern');
    if (ref.mounted && operationId == _operationId && _pattern != null) {
      _clock.start(_pattern!, _bpm);
    }
  }

  @override
  Future<void> stop() async {
    ++_operationId;
    _clock.stop();
    await ref.read(backingTransportProvider.notifier).stop();
  }

  @override
  void setLaneGain(DrumLane lane, double gain) => _gains[lane] = gain;

  @override
  Future<void> dispose() => _clock.dispose();
}

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
    ref.listen<String?>(
      metronomeProvider.select((value) => value.activeSong?.id),
      (_, _) => unawaited(clearPattern()),
    );
    ref.listen<bool>(metronomeProvider.select((value) => value.isPlaying), (
      _,
      playing,
    ) {
      if (!state.syncWithClick || state.pattern == null) return;
      unawaited(playing ? start() : stop());
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

  /// Called when the Drums sheet closes: keep playing only while the click
  /// is driving the drums, otherwise nothing on screen could stop them.
  void releaseUnlessSynced() {
    final clickRunning = ref.read(metronomeProvider).isPlaying;
    if (state.playing && !(state.syncWithClick && clickRunning)) {
      unawaited(stop());
    }
  }

  Future<void> loadPattern(String entryId, MidiPattern pattern) {
    state = state.copyWith(entryId: entryId, pattern: pattern, currentStep: 0);
    return _reload();
  }

  void setSyncWithClick({required bool enabled}) {
    state = state.copyWith(syncWithClick: enabled);
  }

  Future<void> clearPattern() {
    final stopping = stop();
    state = state.copyWith(pattern: null, entryId: null);
    ref.read(drumActiveProvider.notifier).set(null);
    return stopping;
  }

  void toggleMute(DrumLane lane) {
    final muted = {...state.muted};
    if (!muted.remove(lane)) muted.add(lane);
    state = state.copyWith(muted: muted);
    _updateGains();
  }

  void toggleSolo(DrumLane lane) {
    state = state.copyWith(solo: state.solo == lane ? null : lane);
    _updateGains();
  }

  Future<void> start() async {
    if (state.playing || state.pattern == null) return;
    state = state.copyWith(playing: true, currentStep: 0);
    ref.read(drumActiveProvider.notifier).set(state.pattern?.name ?? 'Drums');
    await _reload();
  }

  Future<void> stop() async {
    ++_operationId;
    state = state.copyWith(playing: false, currentStep: 0);
    ref.read(drumActiveProvider.notifier).set(null);
    if (state.pattern != null) await _player.stop();
  }

  Future<void> setSpeed(double speed) async {
    if (!speed.isFinite || speed <= 0) {
      throw ArgumentError.value(speed, 'speed', 'Must be finite and positive');
    }
    if (state.speed == speed) return;
    state = state.copyWith(speed: speed);
    if (state.playing) await _reload();
  }

  void _updateGains() {
    if (_player is _BackingDrumPlayer) {
      unawaited(_reload());
    } else {
      _syncGains();
    }
  }

  void _syncGains() {
    if (state.pattern == null) return;
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
