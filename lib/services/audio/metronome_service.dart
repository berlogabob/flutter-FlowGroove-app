import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/time_signature.dart';
import '../../models/metronome_state.dart';
import '../../providers/data/metronome_provider.dart';

/// MetronomeService - Riverpod-based implementation
///
/// This class is now a thin wrapper around the Riverpod provider
/// for backward compatibility. New code should use [metronomeProvider] directly.
///
/// Usage with Riverpod:
/// ```dart
/// final metronome = ref.watch(metronomeProvider.notifier);
/// final state = ref.watch(metronomeProvider);
/// ```
class MetronomeService {
  final Ref _ref;

  MetronomeService(this._ref);

  MetronomeState get state => _ref.read(metronomeProvider);
  bool get isPlaying => state.isPlaying;
  int get bpm => state.bpm;
  int get currentBeat => state.currentBeat;
  int get beatsPerMeasure => state.beatsPerMeasure;
  TimeSignature get timeSignature => state.timeSignature;
  String get waveType => state.waveType;
  double get volume => state.volume;
  bool get accentEnabled => state.accentEnabled;
  double get accentFrequency => state.accentFrequency;
  double get beatFrequency => state.beatFrequency;
  List<bool> get accentPattern => List.unmodifiable(state.accentPattern);

  /// Start the metronome
  void start(int bpm, int beatsPerMeasure) {
    _ref.read(metronomeProvider.notifier).start(bpm, beatsPerMeasure);
  }

  /// Stop the metronome
  void stop() {
    _ref.read(metronomeProvider.notifier).stop();
  }

  /// Update BPM while playing
  void setBpm(int bpm) {
    _ref.read(metronomeProvider.notifier).setBpm(bpm);
  }

  /// Update beats per measure (backward compatibility)
  void setBeatsPerMeasure(int beats) {
    _ref.read(metronomeProvider.notifier).setBeatsPerMeasure(beats);
  }

  /// Set time signature with numerator and denominator
  void setTimeSignature(TimeSignature ts) {
    _ref.read(metronomeProvider.notifier).setTimeSignature(ts);
  }

  /// Set wave type
  void setWaveType(String type) {
    _ref.read(metronomeProvider.notifier).setWaveType(type);
  }

  /// Set volume
  void setVolume(double vol) {
    _ref.read(metronomeProvider.notifier).setVolume(vol);
  }

  /// Toggle accent
  void setAccentEnabled(bool enabled) {
    _ref.read(metronomeProvider.notifier).setAccentEnabled(enabled);
  }

  /// Set accent frequency
  void setAccentFrequency(double freq) {
    _ref.read(metronomeProvider.notifier).setAccentFrequency(freq);
  }

  /// Set beat frequency
  void setBeatFrequency(double freq) {
    _ref.read(metronomeProvider.notifier).setBeatFrequency(freq);
  }

  /// Set custom accent pattern
  void setAccentPattern(List<bool> pattern) {
    _ref.read(metronomeProvider.notifier).setAccentPattern(pattern);
  }

  /// Auto-generate accent pattern from time signature
  void updateAccentPatternFromTimeSignature() {
    _ref
        .read(metronomeProvider.notifier)
        .updateAccentPatternFromTimeSignature();
  }

  /// Check if a beat index should be accented based on current pattern
  bool isAccentBeat(int beatIndex) {
    return state.isAccentBeat(beatIndex);
  }

  /// Play test sound
  Future<void> playTest() async {
    await _ref.read(metronomeProvider.notifier).playTest();
  }

  /// Toggle play/stop
  void toggle() {
    _ref.read(metronomeProvider.notifier).toggle();
  }
}
