import 'dart:async';
import 'package:flutter/foundation.dart';
import 'audio_engine.dart';
import '../models/time_signature.dart';

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
  TimeSignature _timeSignature = TimeSignature.commonTime; // 4/4
  int _currentBeat = 0;
  String _waveType = 'sine';
  double _volume = 0.5;
  bool _accentEnabled = true;
  double _accentFrequency = 1600; // Hz (Reaper-style)
  double _beatFrequency = 800;    // Hz (Reaper-style)
  List<bool> _accentPattern = [true, false, false, false]; // ABBB for 4/4

  bool get isPlaying => _isPlaying;
  int get bpm => _bpm;
  int get currentBeat => _currentBeat;
  int get beatsPerMeasure => _timeSignature.numerator;
  TimeSignature get timeSignature => _timeSignature;
  String get waveType => _waveType;
  double get volume => _volume;
  bool get accentEnabled => _accentEnabled;
  double get accentFrequency => _accentFrequency;
  double get beatFrequency => _beatFrequency;
  List<bool> get accentPattern => List.unmodifiable(_accentPattern);
  
  /// Start the metronome
  void start(int bpm, int beatsPerMeasure) {
    if (_isPlaying) return;
    
    _bpm = bpm.clamp(40, 220);
    _timeSignature = TimeSignature(numerator: beatsPerMeasure, denominator: _timeSignature.denominator);
    _currentBeat = -1; // Will be 0 on first tick
    _isPlaying = true;
    
    // Auto-generate accent pattern for new time signature
    updateAccentPatternFromTimeSignature();
    
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
  
  /// Update beats per measure (backward compatibility)
  void setBeatsPerMeasure(int beats) {
    _timeSignature = TimeSignature(numerator: beats, denominator: _timeSignature.denominator);
    if (_isPlaying) {
      _timer?.cancel();
      _startTimer();
    }
    notifyListeners();
  }

  /// Set time signature with numerator and denominator
  void setTimeSignature(TimeSignature ts) {
    _timeSignature = ts;
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

  /// Set accent frequency
  void setAccentFrequency(double freq) {
    _accentFrequency = freq;
    notifyListeners();
  }

  /// Set beat frequency
  void setBeatFrequency(double freq) {
    _beatFrequency = freq;
    notifyListeners();
  }
  
  /// Set custom accent pattern
  /// [pattern] - List of booleans where true = accent, false = regular
  void setAccentPattern(List<bool> pattern) {
    if (pattern.isEmpty) return;
    _accentPattern = pattern;
    notifyListeners();
  }
  
  /// Auto-generate accent pattern from time signature
  /// Default: accent on beat 1, regular on all others (e.g., ABBB for 4/4)
  void updateAccentPatternFromTimeSignature() {
    _accentPattern = List.generate(
      _timeSignature.numerator,
      (index) => index == 0, // First beat is accent, rest are regular
    );
    notifyListeners();
  }
  
  /// Check if a beat index should be accented based on current pattern
  bool isAccentBeat(int beatIndex) {
    if (beatIndex < 0 || beatIndex >= _accentPattern.length) return false;
    return _accentPattern[beatIndex];
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
      start(_bpm, _timeSignature.numerator);
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
    
    _currentBeat = (_currentBeat + 1) % _timeSignature.numerator;
    
    // Play sound on each beat
    // Use accent pattern to determine if this beat should be accented
    final isAccent = _accentEnabled && isAccentBeat(_currentBeat);
    _audioEngine.playClick(
      isAccent: isAccent,
      waveType: _waveType,
      volume: _volume,
      accentFrequency: _accentFrequency,
      beatFrequency: _beatFrequency,
    );
    
    notifyListeners();
  }
  
  /// Dispose resources
  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
