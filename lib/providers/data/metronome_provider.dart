import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/metronome_state.dart';
import '../../models/time_signature.dart';
import '../../models/song.dart';
import '../../models/setlist.dart';
import '../../models/beat_mode.dart';
import '../../providers/metronome_runtime_providers.dart';
import '../../providers/wakelock_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/audio/audio_focus_manager.dart';
import '../../services/wakelock_controller.dart';

/// Metronome Notifier class
///
/// Manages metronome state and provides methods to control it.
/// Uses Riverpod Notifier pattern for state management.
class MetronomeNotifier extends Notifier<MetronomeState> {
  late MetronomeAudioClient _audioClient;
  late MetronomePlaybackClient _playbackClient;
  late WakelockController _wakelock;

  /// Default constructor
  MetronomeNotifier();

  Timer? _debounceTimer;
  bool _debouncePending = false;

  @override
  MetronomeState build() {
    _audioClient = ref.read(metronomeAudioClientProvider);
    _playbackClient = ref.read(metronomePlaybackClientProvider);
    _wakelock = ref.read(wakelockProvider);
    ref.onDispose(_cleanup);

    return MetronomeState.initial();
  }

  /// Start the metronome
  void start(int bpm, int beatsPerMeasure) {
    if (state.isPlaying) return;

    final clampedBpm = _clampBpm(bpm);
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

    state = state.copyWith(
      isPlaying: true,
      bpm: clampedBpm,
      timeSignature: timeSignature,
      accentBeats: beatsPerMeasure,
      currentBeat: -1, // Will be 0 on first tick
      accentPattern: accentPattern,
    );

    // Request audio focus for metronome playback
    unawaited(AudioFocusManager().requestFocus());

    unawaited(_startPlaybackSafely(initialTick: -1));

    // Enable wakelock to keep screen on during practice
    unawaited(_wakelock.enable());
  }

  /// Stop the metronome
  void stop() {
    if (!state.isPlaying) return;

    unawaited(_playbackClient.stop());

    state = state.copyWith(isPlaying: false, currentBeat: 0);

    // Release audio focus when metronome stops
    unawaited(AudioFocusManager().releaseFocus());

    // Disable wakelock when metronome stops
    unawaited(_wakelock.disable());
  }

  /// Update BPM while playing
  void setBpm(int bpm) {
    final clampedBpm = _clampBpm(bpm);
    state = state.copyWith(bpm: clampedBpm);
    _syncPlaybackConfig();
  }

  /// Set number of BEATS (top row, first number of time signature)
  /// Examples: 4/4 → 4 beats, 2/2 → 2 beats, 6/8 → 2 beats
  /// INDEPENDENT: Does NOT affect subdivisions count
  void setAccentBeats(int count) {
    final clampedCount = count.clamp(1, 12).toInt();
    state = state.copyWith(accentBeats: clampedCount);
    _syncPlaybackConfig();
  }

  /// Set number of SUBDIVISIONS per beat (bottom row)
  /// Examples: 1 → HHHH, 2 → HlHlHlHl, 3 → HllHllHllHll
  /// Where H = High pitch (1760 Hz), l = Low pitch (880 Hz)
  /// INDEPENDENT: Does NOT affect beats count
  void setRegularBeats(int count) {
    final clampedCount = count.clamp(1, 12).toInt();
    state = state.copyWith(regularBeats: clampedCount);
    _syncPlaybackConfig();
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
    _syncPlaybackConfig();
  }

  /// Rotate tempo using rotary dial gesture
  void rotateTempo(double degrees) {
    final bpmChange = (degrees / 288)
        .round(); // 288 degrees = 1 BPM (4x slower than 72)
    final newBpm = _clampBpm(state.bpm + bpmChange);

    // Stop at limits - don't wrap around
    if (newBpm == state.bpm && (state.bpm == 10 || state.bpm == 260)) {
      return; // At limit, don't update
    }

    state = state.copyWith(bpm: newBpm);
    _syncPlaybackConfig();
  }

  /// Fine adjustment for tempo (+1, +5, +10 buttons)
  void adjustTempoFine(int delta) {
    final newBpm = _clampBpm(state.bpm + delta);
    state = state.copyWith(bpm: newBpm);
    _syncPlaybackConfig();
  }

  /// Load tempo and metronome settings from a song
  void loadSongTempo(Song song) {
    // Load song into state
    state = state.copyWith(loadedSong: song);

    // Load BPM from song (prefer ourBPM, fallback to originalBPM)
    final songBpm = song.ourBPM ?? song.originalBPM;
    if (songBpm != null) {
      final clampedBpm = _clampBpm(songBpm);
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

    _syncPlaybackConfig();
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
    final clampedBpm = _clampBpm(bpm);
    state = state.copyWith(bpm: clampedBpm);
    _syncPlaybackConfig();
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
      accentBeats: beats,
      accentPattern: accentPattern,
    );
    _syncPlaybackConfig();
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
    _syncPlaybackConfig();
  }

  /// Set wave type
  void setWaveType(String type) {
    state = state.copyWith(waveType: type);
    _syncPlaybackConfig();
  }

  /// Set volume
  void setVolume(double volume) {
    final clampedVolume = volume.clamp(0.0, 1.0).toDouble();
    state = state.copyWith(volume: clampedVolume);
    _syncPlaybackConfig();
  }

  /// Toggle accent enabled
  void toggleAccent() {
    state = state.copyWith(accentEnabled: !state.accentEnabled);
    _syncPlaybackConfig();
  }

  /// Set accent enabled state
  void setAccentEnabled(bool enabled) {
    state = state.copyWith(accentEnabled: enabled);
    _syncPlaybackConfig();
  }

  /// Set accent frequency
  void setAccentFrequency(double frequency) {
    state = state.copyWith(accentFrequency: frequency);
    _syncPlaybackConfig();
  }

  /// Set beat frequency
  void setBeatFrequency(double frequency) {
    state = state.copyWith(beatFrequency: frequency);
    _syncPlaybackConfig();
  }

  /// Toggle synchronized haptic feedback during playback.
  void toggleHaptics() {
    setHapticsEnabled(!state.hapticsEnabled);
  }

  /// Set synchronized haptic feedback during playback.
  void setHapticsEnabled(bool enabled) {
    state = state.copyWith(hapticsEnabled: enabled);
    _syncPlaybackConfig();
  }

  /// Set accent pattern
  void setAccentPattern(List<bool> pattern) {
    state = state.copyWith(accentPattern: List.unmodifiable(pattern));
  }

  /// Set count-in bars (0 = off, 1-4 = number of bars to count in)
  void setCountInBars(int bars) {
    final clampedBars = bars.clamp(0, 4).toInt();
    state = state.copyWith(countInBars: clampedBars);
    _syncPlaybackConfig();
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
    await _audioClient.playTest();
  }

  /// Toggle play/stop
  void toggle() {
    if (state.isPlaying) {
      stop();
    } else {
      start(state.bpm, state.timeSignature.numerator);

      // Log analytics event when starting metronome
      AnalyticsService.logMetronomeStarted(
        bpm: state.bpm,
        timeSignature:
            '${state.timeSignature.numerator}/${state.timeSignature.denominator}',
        subdivision: state.regularBeats,
        soundType: 'digital',
      );
    }
  }

  /// Dispose resources when the provider is destroyed
  void dispose() {
    _cleanup();
  }

  int _clampBpm(int bpm) {
    return bpm.clamp(1, 600);
  }

  Future<void> _startPlaybackSafely({required int initialTick}) async {
    try {
      await _playbackClient.start(
        MetronomePlaybackConfig.fromState(state),
        onTick: _handlePlaybackTick,
        onStopped: _handlePlaybackStopped,
        initialTick: initialTick,
      );
    } catch (error) {
      debugPrint('[MetronomeNotifier] Playback start failed: $error');
    }
  }

  Future<void> _updatePlaybackSafely() async {
    try {
      await _playbackClient.update(MetronomePlaybackConfig.fromState(state));
    } catch (error) {
      debugPrint('[MetronomeNotifier] Playback update failed: $error');
    }
  }

  void _syncPlaybackConfig() {
    if (!state.isPlaying) return;
    if (_debouncePending) return;
    _debouncePending = true;
    _debounceTimer = Timer(const Duration(milliseconds: 50), () {
      _debouncePending = false;
      unawaited(_updatePlaybackSafely());
    });
    // Also schedule a microtask to flush after the current frame,
    // so that single calls are processed promptly.
    Future<void>.microtask(() {
      if (_debounceTimer?.isActive ?? false) {
        _debounceTimer?.cancel();
        _debouncePending = false;
        unawaited(_updatePlaybackSafely());
      }
    });
  }

  void _handlePlaybackTick(MetronomePlaybackTick tick) {
    if (!state.isPlaying) return;
    state = state.copyWith(currentBeat: tick.index);
  }

  void _handlePlaybackStopped() {
    if (!state.isPlaying) return;
    state = state.copyWith(isPlaying: false, currentBeat: 0);
    unawaited(_wakelock.disable());
  }

  void _cleanup() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    unawaited(_playbackClient.stop());
    unawaited(AudioFocusManager().releaseFocus());
    if (!_wakelock.isDisposed && _wakelock.isEnabled) {
      unawaited(_wakelock.disable());
    }
  }
}

/// NotifierProvider for metronome state management
final metronomeProvider = NotifierProvider<MetronomeNotifier, MetronomeState>(
  () {
    return MetronomeNotifier();
  },
);
