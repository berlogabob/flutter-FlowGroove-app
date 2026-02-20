import 'dart:async';
import 'package:flutter/foundation.dart';
import 'audio_engine.dart';

/// Simple singleton metronome service - MVP version
/// Visual only for now - no audio dependencies
class MetronomeService extends ChangeNotifier {
  static final MetronomeService _instance = MetronomeService._internal();
  factory MetronomeService() => _instance;
  MetronomeService._internal();
  
  final _audioEngine = AudioEngine();
  Timer? _timer;
  bool _isPlaying = false;
  int _bpm = 120;
  int _beatsPerMeasure = 4;
  int _currentBeat = 0;
  String _waveType = 'sine';
  double _volume = 0.5;
  bool _accentEnabled = true;
  
  bool get isPlaying => _isPlaying;
  int get bpm => _bpm;
  int get currentBeat => _currentBeat;
  int get beatsPerMeasure => _beatsPerMeasure;
  String get waveType => _waveType;
  double get volume => _volume;
  bool get accentEnabled => _accentEnabled;
  
  /// Start the metronome
  void start(int bpm, int beatsPerMeasure) {
    if (_isPlaying) return;
    
    _bpm = bpm.clamp(40, 220);
    _beatsPerMeasure = beatsPerMeasure;
    _currentBeat = -1; // Will be 0 on first tick
    _isPlaying = true;
    
    // Initialize audio on first start (requires user interaction)
    _audioEngine.initialize();
    
    _startTimer();
    notifyListeners();
  }
  
  /// Stop the metronome
  void stop() {
    if (!_isPlaying) return;
    
    _isPlaying = false;
    _timer?.cancel();
    _timer = null;
    _currentBeat = 0;
    
    notifyListeners();
  }
  
  /// Update BPM while playing
  void setBpm(int bpm) {
    _bpm = bpm.clamp(40, 220);
    if (_isPlaying) {
      _timer?.cancel();
      _startTimer();
    }
    notifyListeners();
  }
  
  /// Update beats per measure
  void setBeatsPerMeasure(int beats) {
    _beatsPerMeasure = beats;
    if (_isPlaying) {
      _timer?.cancel();
      _startTimer();
    }
    notifyListeners();
  }
  
  /// Set wave type
  void setWaveType(String type) {
    _waveType = type;
    notifyListeners();
  }
  
  /// Set volume
  void setVolume(double vol) {
    _volume = vol.clamp(0.0, 1.0);
    notifyListeners();
  }
  
  /// Toggle accent
  void setAccentEnabled(bool enabled) {
    _accentEnabled = enabled;
    notifyListeners();
  }
  
  /// Play test sound
  Future<void> playTest() async {
    await _audioEngine.playTest();
  }
  
  /// Toggle play/stop
  void toggle() {
    if (_isPlaying) {
      stop();
    } else {
      start(_bpm, _beatsPerMeasure);
    }
  }
  
  /// Start timer
  void _startTimer() {
    final intervalMs = 60000 ~/ _bpm;
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), _onTick);
  }
  
  /// Handle timer tick
  void _onTick(Timer timer) {
    if (!_isPlaying) return;
    
    _currentBeat = (_currentBeat + 1) % _beatsPerMeasure;
    
    // Play sound on each beat
    final isAccent = _accentEnabled && _currentBeat == 0;
    _audioEngine.playClick(
      isAccent: isAccent,
      waveType: _waveType,
      volume: _volume,
    );
    
    notifyListeners();
  }
  
  /// Dispose resources
  void dispose() {
    stop();
  }
}
