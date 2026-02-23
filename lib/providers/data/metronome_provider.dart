import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/metronome_state.dart';
import '../../models/time_signature.dart';
import '../../models/song.dart';
import '../../models/setlist.dart';
import '../../services/audio/audio_engine.dart';

/// Notifier for metronome state management using Riverpod
///
/// Replaces the old ChangeNotifier-based MetronomeService singleton
/// with a proper Riverpod NotifierProvider pattern.
class MetronomeNotifier extends Notifier<MetronomeState> {
  final _audioEngine = AudioEngine();
  Timer? _timer;

  @override
  MetronomeState build() {
    return MetronomeState.initial();
  }

  /// Start the metronome
  void start(int bpm, int beatsPerMeasure) {
    if (state.isPlaying) return;

    final clampedBpm = bpm.clamp(40, 220);
    final timeSignature = TimeSignature(
      numerator: beatsPerMeasure,
      denominator: state.timeSignature.denominator,
    );

    // Auto-generate accent pattern for new time signature
    // Special case 6/8: accents on 1st and 4th subdivisions
    List<bool> accentPattern;
    if (beatsPerMeasure == 6 && timeSignature.denominator == 8) {
      accentPattern = [true, true]; // 2 main beats, both accented
    } else {
      accentPattern = List.generate(
        beatsPerMeasure,
        (index) => index == 0, // First beat is accent, rest are regular
      );
    }

    // Initialize audio on first start (requires user interaction)
    _audioEngine.initialize();

    state = state.copyWith(
      isPlaying: true,
      bpm: clampedBpm,
      timeSignature: timeSignature,
      currentBeat: -1, // Will be 0 on first tick
      accentPattern: accentPattern,
    );

    _startTimer();
  }

  /// Stop the metronome
  void stop() {
    if (!state.isPlaying) return;

    _timer?.cancel();
    _timer = null;

    state = state.copyWith(isPlaying: false, currentBeat: 0);
  }

  /// Update BPM while playing
  void setBpm(int bpm) {
    final clampedBpm = bpm.clamp(40, 220);
    state = state.copyWith(bpm: clampedBpm);

    if (state.isPlaying) {
      _timer?.cancel();
      _startTimer();
    }
  }

  /// Update beats per measure (backward compatibility)
  /// Handles special cases per Help:
  /// - 4/4 → 4 beats
  /// - 2/2 → 2 beats
  /// - 6/8 → 2 beats (+ subdivisions on 1st and 4th)
  void setBeatsPerMeasure(int beats) {
    final timeSignature = TimeSignature(
      numerator: beats,
      denominator: state.timeSignature.denominator,
    );

    // Auto-generate new accent pattern for the new time signature
    // Special case 6/8: accents on 1st and 4th subdivisions
    List<bool> accentPattern;
    if (beats == 6 && timeSignature.denominator == 8) {
      accentPattern = [true, true]; // 2 main beats, both accented
    } else {
      accentPattern = List.generate(beats, (index) => index == 0);
    }

    state = state.copyWith(
      timeSignature: timeSignature,
      accentPattern: accentPattern,
    );

    if (state.isPlaying) {
      _timer?.cancel();
      _startTimer();
    }
  }

  /// Set time signature with numerator and denominator
  /// Handles special cases per Help:
  /// - 4/4 → 4 beats
  /// - 2/2 → 2 beats
  /// - 6/8 → 2 beats (+ subdivisions on 1st and 4th)
  /// INDEPENDENT: Does NOT override manual accent pattern changes
  void setTimeSignature(TimeSignature ts) {
    int beatCount;
    List<bool> accentPattern;

    // Special handling for 6/8: 2 beats with subdivisions
    if (ts.numerator == 6 && ts.denominator == 8) {
      beatCount = 2;
      // Subdivisions: strong on 1st and 4th (A A for the two main beats)
      accentPattern = [true, true];
    } else {
      // Default: beat count = numerator
      beatCount = ts.numerator;
      // Auto-generate: accent on beat 1, regular on all others
      accentPattern = List.generate(beatCount, (index) => index == 0);
    }

    state = state.copyWith(
      timeSignature: ts,
      regularBeats: beatCount,
      accentBeats: accentPattern.where((a) => a).length,
      accentPattern: accentPattern,
    );

    if (state.isPlaying) {
      _timer?.cancel();
      _startTimer();
    }
  }

  /// Set wave type
  void setWaveType(String type) {
    state = state.copyWith(waveType: type);
  }

  /// Set volume
  void setVolume(double vol) {
    state = state.copyWith(volume: vol.clamp(0.0, 1.0));
  }

  /// Toggle accent
  void setAccentEnabled(bool enabled) {
    state = state.copyWith(accentEnabled: enabled);
  }

  /// Set accent frequency
  void setAccentFrequency(double freq) {
    state = state.copyWith(accentFrequency: freq);
  }

  /// Set beat frequency
  void setBeatFrequency(double freq) {
    state = state.copyWith(beatFrequency: freq);
  }

  /// Set custom accent pattern
  /// [pattern] - List of booleans where true = accent, false = regular
  void setAccentPattern(List<bool> pattern) {
    if (pattern.isEmpty) return;
    state = state.copyWith(accentPattern: List.unmodifiable(pattern));
  }

  /// Auto-generate accent pattern from time signature
  /// Default: accent on beat 1, regular on all others (e.g., ABBB for 4/4)
  /// Special case 6/8: accents on 1st and 4th subdivisions (A A)
  void updateAccentPatternFromTimeSignature() {
    final ts = state.timeSignature;
    List<bool> accentPattern;

    // Special handling for 6/8
    if (ts.numerator == 6 && ts.denominator == 8) {
      accentPattern = [true, true]; // Accents on both main beats
    } else {
      accentPattern = List.generate(ts.numerator, (index) => index == 0);
    }

    state = state.copyWith(accentPattern: accentPattern);
  }

  /// Play test sound
  Future<void> playTest() async {
    await _audioEngine.playTest();
  }

  /// Toggle play/stop
  void toggle() {
    if (state.isPlaying) {
      stop();
    } else {
      start(state.bpm, state.timeSignature.numerator);
    }
  }

  // ============================================================
  // NEW METHODS FOR MONO PULSE UI
  // ============================================================

  /// Set number of accent beats (top row in time signature block)
  /// INDEPENDENT: Does NOT affect regular beats count
  void setAccentBeats(int count) {
    final clampedCount = count.clamp(1, 12);
    state = state.copyWith(accentBeats: clampedCount);
    // NOTE: accentPattern is managed separately via setAccentPattern()
    // This method only updates the accentBeats counter for UI
  }

  /// Set number of regular beats (bottom row in time signature block)
  /// INDEPENDENT: Does NOT affect accent pattern or accentBeats
  void setRegularBeats(int count) {
    final clampedCount = count.clamp(1, 12); // Max 12 beats
    state = state.copyWith(regularBeats: clampedCount);
    // NOTE: accentPattern is managed separately via setAccentPattern()
    // This method only updates the regularBeats counter for UI
  }

  /// Rotate tempo using rotary dial gesture
  /// [degrees] - rotation angle (positive = clockwise = increase BPM)
  void rotateTempo(double degrees) {
    // Convert degrees to BPM change (e.g., 360 degrees = 60 BPM change)
    final bpmChange = (degrees / 6).round(); // 6 degrees = 1 BPM
    final newBpm = (state.bpm + bpmChange).clamp(1, 600);
    state = state.copyWith(bpm: newBpm);

    if (state.isPlaying) {
      _timer?.cancel();
      _startTimer();
    }
  }

  /// Fine adjustment for tempo (+1, +5, +10 buttons)
  void adjustTempoFine(int delta) {
    final newBpm = (state.bpm + delta).clamp(1, 600);
    state = state.copyWith(bpm: newBpm);

    if (state.isPlaying) {
      _timer?.cancel();
      _startTimer();
    }
  }

  /// Load tempo from a song
  void loadSongTempo(Song song) {
    final bpm = song.ourBPM ?? song.originalBPM ?? 120;
    state = state.copyWith(
      bpm: bpm.clamp(1, 600),
      loadedSong: song,
      loadedSetlist: null,
      currentSetlistIndex: 0,
    );
  }

  /// Load setlist queue for navigation
  void loadSetlistQueue(Setlist setlist) {
    state = state.copyWith(
      loadedSetlist: setlist,
      loadedSong: null,
      currentSetlistIndex: 0,
    );
  }

  /// Navigate to next song in setlist
  void nextSetlistSong() {
    if (state.loadedSetlist == null) return;
    final newIndex = state.currentSetlistIndex + 1;
    if (newIndex < state.loadedSetlist!.songIds.length) {
      state = state.copyWith(currentSetlistIndex: newIndex);
    }
  }

  /// Navigate to previous song in setlist
  void previousSetlistSong() {
    if (state.loadedSetlist == null) return;
    final newIndex = state.currentSetlistIndex - 1;
    if (newIndex >= 0) {
      state = state.copyWith(currentSetlistIndex: newIndex);
    }
  }

  /// Clear loaded song/setlist
  void clearLoadedContent() {
    state = state.copyWith(
      loadedSong: null,
      loadedSetlist: null,
      currentSetlistIndex: 0,
    );
  }

  /// Set tempo directly (for keyboard input)
  void setTempoDirectly(int bpm) {
    final newBpm = bpm.clamp(1, 600);
    state = state.copyWith(bpm: newBpm);

    if (state.isPlaying) {
      _timer?.cancel();
      _startTimer();
    }
  }

  /// Start timer
  void _startTimer() {
    final intervalMs = 60000 ~/ state.bpm;
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), _onTick);
  }

  /// Handle timer tick
  void _onTick(Timer timer) {
    if (!state.isPlaying) return;

    // FIX: Use regularBeats instead of timeSignature.numerator
    // This ensures user adjustments to beat count affect playback
    final nextBeat = (state.currentBeat + 1) % state.regularBeats;

    // Play sound on each beat
    // Use accent pattern to determine if this beat should be accented
    final isAccent = state.accentEnabled && state.isAccentBeat(nextBeat);
    _audioEngine.playClick(
      isAccent: isAccent,
      waveType: state.waveType,
      volume: state.volume,
      accentFrequency: state.accentFrequency,
      beatFrequency: state.beatFrequency,
    );

    state = state.copyWith(currentBeat: nextBeat);
  }

  /// Dispose resources when the provider is destroyed
  void dispose() {
    _timer?.cancel();
    _audioEngine.dispose();
  }
}

/// NotifierProvider for metronome state management
///
/// Usage:
/// ```dart
/// // In a widget
/// final metronome = ref.watch(metronomeProvider.notifier);
/// final state = ref.watch(metronomeProvider);
///
/// // Start metronome
/// metronome.start(120, 4);
///
/// // Access state
/// print(state.isPlaying); // true/false
/// print(state.bpm); // 120
/// ```
final metronomeProvider = NotifierProvider<MetronomeNotifier, MetronomeState>(
  () {
    return MetronomeNotifier();
  },
);
