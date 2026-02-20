import 'package:flutter/foundation.dart';
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

/// Provider for MetronomeController
final metronomeControllerProvider = Provider<MetronomeController>((ref) {
  final controller = MetronomeController(ref.watch(metronomeServiceProvider));
  ref.onDispose(() => controller.dispose());
  return controller;
});

/// Controller for metronome (extends ChangeNotifier)
class MetronomeController extends ChangeNotifier {
  final MetronomeService _service;
  bool _isPlaying = false;
  int _bpm = 120;
  int _currentBeat = 0;
  int _beatsPerMeasure = 4;
  double _volume = 0.5;

  MetronomeController(this._service) {
    _service.onBeatChanged = _onBeatChanged;
  }

  void _onBeatChanged(int beat) {
    _currentBeat = beat;
    notifyListeners();
  }

  bool get isPlaying => _isPlaying;
  int get bpm => _bpm;
  int get currentBeat => _currentBeat;
  int get beatsPerMeasure => _beatsPerMeasure;
  double get volume => _volume;

  /// Start the metronome
  Future<void> start() async {
    if (!_isPlaying) {
      await _service.start(_bpm, _beatsPerMeasure, _volume);
      _isPlaying = true;
      notifyListeners();
    }
  }

  /// Stop the metronome
  Future<void> stop() async {
    if (_isPlaying) {
      await _service.stop();
      _isPlaying = false;
      _currentBeat = 0;
      notifyListeners();
    }
  }

  /// Toggle play/stop
  Future<void> toggle() async {
    if (_isPlaying) {
      await stop();
    } else {
      await start();
    }
  }

  /// Set BPM (40-220)
  void setBpm(int bpm) {
    _bpm = bpm.clamp(40, 220);
    if (_isPlaying) {
      _service.setBpm(_bpm);
    }
    notifyListeners();
  }

  /// Set beats per measure (time signature)
  void setBeatsPerMeasure(int beats) {
    _beatsPerMeasure = beats;
    if (_isPlaying) {
      _service.setBeatsPerMeasure(beats);
    }
    notifyListeners();
  }

  /// Set volume (0.0-1.0)
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    _service.setVolume(_volume);
    notifyListeners();
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
