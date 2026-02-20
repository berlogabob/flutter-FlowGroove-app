import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/metronome_service.dart';

/// Metronome state class
class MetronomeState {
  final bool isPlaying;
  final int bpm;
  final int currentBeat;
  final int beatsPerMeasure;
  final double volume;

  const MetronomeState({
    this.isPlaying = false,
    this.bpm = 120,
    this.currentBeat = 0,
    this.beatsPerMeasure = 4,
    this.volume = 0.5,
  });

  MetronomeState copyWith({
    bool? isPlaying,
    int? bpm,
    int? currentBeat,
    int? beatsPerMeasure,
    double? volume,
  }) {
    return MetronomeState(
      isPlaying: isPlaying ?? this.isPlaying,
      bpm: bpm ?? this.bpm,
      currentBeat: currentBeat ?? this.currentBeat,
      beatsPerMeasure: beatsPerMeasure ?? this.beatsPerMeasure,
      volume: volume ?? this.volume,
    );
  }
}

/// Provider for MetronomeService
final metronomeServiceProvider = Provider<MetronomeService>((ref) {
  return MetronomeService();
});

/// Provider for MetronomeState
final metronomeStateProvider = StateNotifierProvider<MetronomeNotifier, MetronomeState>((ref) {
  return MetronomeNotifier(ref.watch(metronomeServiceProvider));
});

/// StateNotifier for metronome
class MetronomeNotifier extends StateNotifier<MetronomeState> {
  final MetronomeService _service;

  MetronomeNotifier(this._service) : super(const MetronomeState()) {
    _service.onBeatChanged = _onBeatChanged;
  }

  void _onBeatChanged(int beat) {
    state = state.copyWith(currentBeat: beat);
  }

  /// Start the metronome
  Future<void> start() async {
    if (!state.isPlaying) {
      await _service.start(state.bpm, state.beatsPerMeasure, state.volume);
      state = state.copyWith(isPlaying: true);
    }
  }

  /// Stop the metronome
  Future<void> stop() async {
    if (state.isPlaying) {
      await _service.stop();
      state = state.copyWith(isPlaying: false, currentBeat: 0);
    }
  }

  /// Toggle play/stop
  Future<void> toggle() async {
    if (state.isPlaying) {
      await stop();
    } else {
      await start();
    }
  }

  /// Set BPM (40-220)
  void setBpm(int bpm) {
    final clamped = bpm.clamp(40, 220);
    state = state.copyWith(bpm: clamped);
    if (state.isPlaying) {
      _service.setBpm(clamped);
    }
  }

  /// Set beats per measure (time signature)
  void setBeatsPerMeasure(int beats) {
    state = state.copyWith(beatsPerMeasure: beats);
    if (state.isPlaying) {
      _service.setBeatsPerMeasure(beats);
    }
  }

  /// Set volume (0.0-1.0)
  void setVolume(double volume) {
    final clamped = volume.clamp(0.0, 1.0);
    state = state.copyWith(volume: clamped);
    _service.setVolume(clamped);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}

/// Helper to get time signature label
String getTimeSignatureLabel(int beats) {
  switch (beats) {
    case 2:
      return '2/4';
    case 3:
      return '3/4';
    case 4:
      return '4/4';
    case 5:
      return '5/4';
    case 6:
      return '6/8';
    case 7:
      return '7/8';
    default:
      return '$beats/4';
  }
}
