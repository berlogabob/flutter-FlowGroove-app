import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// Metronome service that handles timing and sound playback
class MetronomeService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  Timer? _timer;
  bool _isPlaying = false;
  int _bpm = 120;
  int _beatsPerMeasure = 4;
  int _currentBeat = 0;
  double _volume = 0.5;
  
  /// Callback when beat changes
  Function(int)? onBeatChanged;
  
  /// Start the metronome
  Future<void> start(int bpm, int beatsPerMeasure, double volume) async {
    if (_isPlaying) return;
    
    _bpm = bpm.clamp(40, 220);
    _beatsPerMeasure = beatsPerMeasure;
    _volume = volume.clamp(0.0, 1.0);
    _currentBeat = 0;
    _isPlaying = true;
    
    // Preload sounds
    await _preloadSounds();
    
    // Start timer
    _startTimer();
  }
  
  /// Stop the metronome
  Future<void> stop() async {
    if (!_isPlaying) return;
    
    _isPlaying = false;
    _timer?.cancel();
    _timer = null;
    _currentBeat = 0;
    
    await _audioPlayer.stop();
  }
  
  /// Update BPM while playing
  void setBpm(int bpm) {
    _bpm = bpm.clamp(40, 220);
    if (_isPlaying) {
      _timer?.cancel();
      _startTimer();
    }
  }
  
  /// Update beats per measure
  void setBeatsPerMeasure(int beats) {
    _beatsPerMeasure = beats;
  }
  
  /// Update volume
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    _audioPlayer.setVolume(_volume);
  }
  
  /// Start the timer
  void _startTimer() {
    final interval = Duration(milliseconds: (60000 / _bpm).round());
    _timer = Timer.periodic(interval, _onTick);
  }
  
  /// Handle timer tick
  void _onTick(Timer timer) {
    if (!_isPlaying) return;
    
    _currentBeat = (_currentBeat + 1) % _beatsPerMeasure;
    _playBeat(_currentBeat);
    onBeatChanged?.call(_currentBeat);
  }
  
  /// Play beat sound
  Future<void> _playBeat(int beat) async {
    try {
      // First beat of measure gets accent (higher pitch)
      final isAccent = beat == 0;
      await _audioPlayer.play(
        AssetSource(isAccent ? 'sounds/metronome_accent.mp3' : 'sounds/metronome_click.mp3'),
        volume: _volume,
      );
    } catch (e) {
      // If sound fails, use fallback beep
      debugPrint('Metronome sound error: $e');
    }
  }
  
  /// Preload sounds
  Future<void> _preloadSounds() async {
    try {
      await _audioPlayer.setSource(AssetSource('sounds/metronome_click.mp3'));
      await _audioPlayer.setVolume(_volume);
    } catch (e) {
      debugPrint('Metronome preload error: $e');
    }
  }
  
  /// Check if currently playing
  bool get isPlaying => _isPlaying;
  
  /// Get current BPM
  int get bpm => _bpm;
  
  /// Get current beat
  int get currentBeat => _currentBeat;
  
  /// Get beats per measure
  int get beatsPerMeasure => _beatsPerMeasure;
  
  /// Dispose resources
  void dispose() {
    stop();
    _audioPlayer.dispose();
  }
}
