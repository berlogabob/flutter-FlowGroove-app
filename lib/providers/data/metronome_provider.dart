import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/metronome_state.dart';
import '../../models/time_signature.dart';
import '../../models/song.dart';
import '../../models/setlist.dart';
import '../../models/beat_mode.dart';
import '../../services/audio/audio_engine_export.dart';

/// Metronome Notifier class
///
/// Manages metronome state and provides methods to control it.
/// Uses Riverpod Notifier pattern for state management.
class MetronomeNotifier extends Notifier<MetronomeState> {
  Timer? _timer;
  final AudioEngine _audioEngine = AudioEngine();

  /// Default constructor
  MetronomeNotifier();

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
    List<bool> accentPattern;
    if (beatsPerMeasure == 6 && timeSignature.denominator == 8) {
      accentPattern = [true, true]; // 2 main beats for 6/8
    } else {
      accentPattern = List.generate(
        beatsPerMeasure,
        (index) => index == 0, // First beat is accent
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

  /// Set number of BEATS (top row, first number of time signature)
  /// Examples: 4/4 → 4 beats, 2/2 → 2 beats, 6/8 → 2 beats
  /// INDEPENDENT: Does NOT affect subdivisions count
  void setAccentBeats(int count) {
    final clampedCount = count.clamp(1, 12);
    state = state.copyWith(accentBeats: clampedCount);
  }

  /// Set number of SUBDIVISIONS per beat (bottom row)
  /// Examples: 1 → HHHH, 2 → HlHlHlHl, 3 → HllHllHllHll
  /// Where H = High pitch (1760 Hz), l = Low pitch (880 Hz)
  /// INDEPENDENT: Does NOT affect beats count
  void setRegularBeats(int count) {
    final clampedCount = count.clamp(1, 12);
    state = state.copyWith(regularBeats: clampedCount);
  }

  /// Set beat mode for individual beat (normal, accent, silent)
  /// [beatIndex] - index of the beat (0-based)
  /// [subdivisionIndex] - index of the subdivision within the beat (0-based)
  /// [mode] - BeatMode (normal, accent, silent)
  void setBeatMode(int beatIndex, int subdivisionIndex, BeatMode mode) {
    final newBeatModes = List<List<BeatMode>>.from(
      state.beatModes.map((beat) => List<BeatMode>.from(beat)),
    );

    // Extend outer list if needed (add new beats)
    while (newBeatModes.length <= beatIndex) {
      newBeatModes.add([]);
    }

    // Extend inner list if needed (add subdivisions to this beat)
    while (newBeatModes[beatIndex].length <= subdivisionIndex) {
      newBeatModes[beatIndex].add(BeatMode.normal);
    }

    // Set the mode for this specific subdivision
    newBeatModes[beatIndex][subdivisionIndex] = mode;

    state = state.copyWith(beatModes: List.unmodifiable(newBeatModes));
  }

  /// Rotate tempo using rotary dial gesture
  void rotateTempo(double degrees) {
    final bpmChange = (degrees / 288)
        .round(); // 288 degrees = 1 BPM (4x slower than 72)
    final newBpm = (state.bpm + bpmChange).clamp(1, 300);

    // Stop at limits - don't wrap around
    if (newBpm == state.bpm && (state.bpm == 1 || state.bpm == 300)) {
      return; // At limit, don't update
    }

    state = state.copyWith(bpm: newBpm);

    if (state.isPlaying) {
      _timer?.cancel();
      _startTimer();
    }
  }

  /// Fine adjustment for tempo (+1, +5, +10 buttons)
  void adjustTempoFine(int delta) {
    final newBpm = (state.bpm + delta).clamp(1, 300);
    state = state.copyWith(bpm: newBpm);

    if (state.isPlaying) {
      _timer?.cancel();
      _startTimer();
    }
  }

  /// Load tempo and metronome settings from a song
  void loadSongTempo(Song song) {
    // Load song into state
    state = state.copyWith(loadedSong: song);

    // Load BPM from song (prefer ourBPM, fallback to originalBPM)
    final songBpm = song.ourBPM ?? song.originalBPM;
    if (songBpm != null) {
      final clampedBpm = songBpm.clamp(1, 300);
      state = state.copyWith(bpm: clampedBpm);
    }

    // Load metronome settings from song
    state = state.copyWith(
      accentBeats: song.accentBeats,
      regularBeats: song.regularBeats,
      beatModes: song.beatModes.isNotEmpty ? song.beatModes : state.beatModes,
    );

    // Update time signature to match loaded accentBeats
    final timeSignature = TimeSignature(
      numerator: song.accentBeats,
      denominator: state.timeSignature.denominator,
    );
    state = state.copyWith(timeSignature: timeSignature);

    // Stop metronome if playing to apply new settings
    if (state.isPlaying) {
      _timer?.cancel();
      _startTimer();
    }
  }

  /// Save current metronome settings to the loaded song
  ///
  /// Returns the updated song with metronome settings applied.
  /// The caller is responsible for persisting the song to Firestore.
  Song? saveMetronomeToSong() {
    final song = state.loadedSong;
    if (song == null) return null;

    // Create updated song with current metronome settings
    final updatedSong = song.copyWith(
      accentBeats: state.accentBeats,
      regularBeats: state.regularBeats,
      beatModes: state.beatModes,
      ourBPM: state.bpm, // Save current BPM as ourBPM
      updatedAt: DateTime.now(),
    );

    // Update loaded song in state
    state = state.copyWith(loadedSong: updatedSong);

    return updatedSong;
  }

  /// Load tempo from a setlist
  void loadSetlistQueue(Setlist setlist) {
    state = state.copyWith(loadedSetlist: setlist, currentSetlistIndex: 0);
  }

  /// Move to next song in setlist
  void nextSetlistSong() {
    if (state.loadedSetlist == null) return;

    final newIndex = state.currentSetlistIndex + 1;
    if (newIndex < state.loadedSetlist!.songIds.length) {
      state = state.copyWith(currentSetlistIndex: newIndex);
    }
  }

  /// Move to previous song in setlist
  void previousSetlistSong() {
    if (state.loadedSetlist == null) return;

    if (state.currentSetlistIndex > 0) {
      state = state.copyWith(
        currentSetlistIndex: state.currentSetlistIndex - 1,
      );
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

  /// Set tempo directly
  void setTempoDirectly(int bpm) {
    final clampedBpm = bpm.clamp(1, 300);
    state = state.copyWith(bpm: clampedBpm);

    if (state.isPlaying) {
      _timer?.cancel();
      _startTimer();
    }
  }

  /// Update beats per measure (backward compatibility)
  void setBeatsPerMeasure(int beats) {
    final timeSignature = TimeSignature(
      numerator: beats,
      denominator: state.timeSignature.denominator,
    );

    // Auto-generate new accent pattern
    List<bool> accentPattern;
    if (beats == 6 && timeSignature.denominator == 8) {
      accentPattern = [true, true];
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
  void setTimeSignature(TimeSignature ts) {
    int beatCount;
    List<bool> accentPattern;

    // Special handling for 6/8: 2 beats with subdivisions
    if (ts.numerator == 6 && ts.denominator == 8) {
      beatCount = 2;
      accentPattern = [true, true];
    } else {
      beatCount = ts.numerator;
      accentPattern = List.generate(beatCount, (index) => index == 0);
    }

    state = state.copyWith(
      timeSignature: ts,
      accentBeats: beatCount,
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
  void setVolume(double volume) {
    final clampedVolume = volume.clamp(0.0, 1.0);
    state = state.copyWith(volume: clampedVolume);
  }

  /// Toggle accent enabled
  void toggleAccent() {
    state = state.copyWith(accentEnabled: !state.accentEnabled);
  }

  /// Set accent enabled state
  void setAccentEnabled(bool enabled) {
    state = state.copyWith(accentEnabled: enabled);
  }

  /// Set accent frequency
  void setAccentFrequency(double frequency) {
    state = state.copyWith(accentFrequency: frequency);
  }

  /// Set beat frequency
  void setBeatFrequency(double frequency) {
    state = state.copyWith(beatFrequency: frequency);
  }

  /// Set accent pattern
  void setAccentPattern(List<bool> pattern) {
    state = state.copyWith(accentPattern: List.unmodifiable(pattern));
  }

  /// Update accent pattern from time signature
  void updateAccentPatternFromTimeSignature() {
    final ts = state.timeSignature;
    List<bool> accentPattern;

    if (ts.numerator == 6 && ts.denominator == 8) {
      accentPattern = [true, true];
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

  /// Start timer based on current BPM
  void _startTimer() {
    final interval = Duration(
      milliseconds: (60000 ~/ state.bpm).clamp(1, 1500),
    );
    _timer = Timer.periodic(interval, _onTick);
  }

  /// Handle timer tick
  /// NEW LOGIC: H/l pitch based on subdivision + beat modes
  /// CRITICAL: Each subdivision has INDEPENDENT mode (not inherited from parent beat)
  void _onTick(Timer timer) {
    if (!state.isPlaying) return;

    // Calculate total ticks per measure
    // accentBeats = BEATS count (top row)
    // regularBeats = SUBDIVISIONS per beat (bottom row)
    final totalTicks = state.accentBeats * state.regularBeats;
    final nextTick = (state.currentBeat + 1) % totalTicks;

    // Determine which beat we're on (0 to accentBeats-1)
    final currentBeatIndex = nextTick ~/ state.regularBeats;

    // Determine which subdivision within the beat (0 to regularBeats-1)
    final currentSubdivisionIndex = nextTick % state.regularBeats;

    // Determine if this is a main beat position (first subdivision of the beat)
    final isMainBeat = currentSubdivisionIndex == 0;

    // Get mode for THIS specific subdivision (INDEPENDENT from parent beat!)
    final beatMode =
        currentBeatIndex < state.beatModes.length &&
            currentSubdivisionIndex < state.beatModes[currentBeatIndex].length
        ? state.beatModes[currentBeatIndex][currentSubdivisionIndex]
        : BeatMode.normal;

    // Calculate frequency based on mode (INDEPENDENT subdivision mode)
    double frequency;
    bool shouldPlay = true;

    if (beatMode == BeatMode.silent) {
      // Silent mode: visual only, no sound
      shouldPlay = false;
      frequency = isMainBeat ? 1760.0 : 880.0;
    } else if (beatMode == BeatMode.accent) {
      // Accent mode: +300 Hz (INDEPENDENT of parent beat)
      frequency = (isMainBeat ? 1760.0 : 880.0) + 300.0;
    } else {
      // Normal mode
      frequency = isMainBeat ? 1760.0 : 880.0;
    }

    // Play sound if not silent
    if (shouldPlay) {
      _audioEngine.playClick(
        isAccent: isMainBeat,
        waveType: state.waveType,
        volume: state.volume,
        accentFrequency: frequency,
        beatFrequency: frequency,
      );
    }

    state = state.copyWith(currentBeat: nextTick);
  }

  /// Dispose resources when the provider is destroyed
  void dispose() {
    _timer?.cancel();
    _audioEngine.dispose();
  }
}

/// NotifierProvider for metronome state management
final metronomeProvider = NotifierProvider<MetronomeNotifier, MetronomeState>(
  () {
    return MetronomeNotifier();
  },
);
