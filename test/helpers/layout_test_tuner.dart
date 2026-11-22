import 'package:flowgroove/providers/tuner_provider.dart';
import 'package:flowgroove/services/audio/pitch_analysis.dart';

class StabilityTuner extends TunerNotifier {
  StabilityTuner(this.initialMode);

  final TunerMode initialMode;

  @override
  TunerState build() => TunerState(mode: initialMode);

  bool get active => state.isPlaying || state.isListening;

  @override
  Future<void> togglePlaying() async {
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  @override
  Future<void> toggleListening() async {
    state = state.copyWith(
      isListening: !state.isListening,
      isStarting: false,
      signalState: state.isListening
          ? TunerSignalState.idle
          : TunerSignalState.noSignal,
    );
  }

  void detectPitch() => state = state.copyWith(
    note: 'F#4',
    frequency: 370.3,
    cents: -13,
    signalState: TunerSignalState.detected,
    inputLevelDb: -35,
  );

  @override
  Future<void> stopAll() async {}
}
