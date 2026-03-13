import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio/tone_generator.dart';
import '../services/audio/pitch_detector.dart';
import '../services/analytics_service.dart';

/// Tuner modes
enum TunerMode {
  /// Generate Tone mode - creates sine wave tones
  generate,

  /// Listen & Tune mode - detects pitch from microphone
  listen,
}

/// Note data class for frequency/note conversion
class NoteData {
  final String note;
  final int octave;
  final double frequency;

  const NoteData({
    required this.note,
    required this.octave,
    required this.frequency,
  });

  String get displayName => '$note$octave';

  @override
  String toString() => displayName;
}

/// Tuner State class
class TunerState {
  /// Current mode (Generate or Listen)
  final TunerMode mode;

  /// Current frequency in Hz (20-2000 Hz)
  final double frequency;

  /// Current note name (e.g., "A4")
  final String note;

  /// Cents deviation (-50 to +50)
  final int cents;

  /// Whether audio is currently playing
  final bool isPlaying;

  /// Whether microphone is currently listening
  final bool isListening;

  /// Volume level (0.0 to 1.0)
  final double volume;

  const TunerState({
    this.mode = TunerMode.listen,
    this.frequency = 440.0,
    this.note = 'A4',
    this.cents = 0,
    this.isPlaying = false,
    this.isListening = false,
    this.volume = 0.5,
  });

  TunerState copyWith({
    TunerMode? mode,
    double? frequency,
    String? note,
    int? cents,
    bool? isPlaying,
    bool? isListening,
    double? volume,
  }) {
    return TunerState(
      mode: mode ?? this.mode,
      frequency: frequency ?? this.frequency,
      note: note ?? this.note,
      cents: cents ?? this.cents,
      isPlaying: isPlaying ?? this.isPlaying,
      isListening: isListening ?? this.isListening,
      volume: volume ?? this.volume,
    );
  }

  @override
  String toString() {
    return 'TunerState(mode: $mode, frequency: ${frequency.toStringAsFixed(1)} Hz, '
        'note: $note, cents: $cents, isPlaying: $isPlaying, isListening: $isListening)';
  }

  /// Create initial state
  static TunerState initial() => const TunerState();
}

/// Notifier for tuner state management using Riverpod
class TunerNotifier extends Notifier<TunerState> {
  final _toneGenerator = ToneGenerator();
  final _pitchDetector = PitchDetector();
  int _previousCents = 0;

  @override
  TunerState build() {
    return TunerState.initial();
  }

  void dispose() {
    stopPlaying();
    stopListening();
    _toneGenerator.dispose();
    _pitchDetector.dispose();
  }

  /// Switch between Generate and Listen modes
  Future<void> setMode(TunerMode mode) async {
    if (state.mode == mode) return;

    // Stop current activity when switching modes
    if (state.isPlaying) {
      await stopPlaying();
    }
    if (state.isListening) {
      await stopListening();
    }

    state = state.copyWith(mode: mode);
  }

  /// Update frequency by dragging (rotation gesture)
  void updateFrequency(double frequency) {
    // Clamp to valid range (20 Hz - 2000 Hz)
    final clampedFrequency = frequency.clamp(20.0, 2000.0);
    final noteData = _frequencyToNote(clampedFrequency);

    state = state.copyWith(
      frequency: clampedFrequency,
      note: noteData.displayName,
    );
  }

  /// Set frequency directly
  void setFrequency(double frequency) {
    updateFrequency(frequency);
  }

  /// Start playing the tone (Generate mode)
  Future<void> startPlaying() async {
    if (state.mode != TunerMode.generate) return;
    if (state.isPlaying) return;

    try {
      await _toneGenerator.startTone(state.frequency, state.volume);
      state = state.copyWith(isPlaying: true);
    } catch (e) {
      debugPrint('Error starting tone: $e');
    }
  }

  /// Stop playing the tone
  Future<void> stopPlaying() async {
    if (!state.isPlaying) return;

    try {
      await _toneGenerator.stopTone();
      state = state.copyWith(isPlaying: false);
    } catch (e) {
      debugPrint('Error stopping tone: $e');
    }
  }

  /// Toggle play/stop
  Future<void> togglePlaying() async {
    if (state.isPlaying) {
      await stopPlaying();
    } else {
      await startPlaying();
      // Log analytics event
      AnalyticsService.logTunerUsed(
        mode: 'generate',
        targetNote: state.note,
      );
    }
  }

  /// Start listening to microphone (Listen mode)
  ///
  /// Stage 3: Real pitch detection using YIN algorithm
  Future<void> startListening() async {
    if (state.mode != TunerMode.listen) return;
    if (state.isListening) return;

    try {
      // Request permissions first
      final hasPermission = await _pitchDetector.requestPermission();
      if (!hasPermission) {
        debugPrint('Microphone permission denied');
        return;
      }

      // Set up pitch detection callback before starting
      _pitchDetector.onPitchDetected = _handlePitchDetection;

      await _pitchDetector.startListening();
      state = state.copyWith(isListening: true);
      
      // Log analytics event
      AnalyticsService.logTunerUsed(
        mode: 'listen',
        detectedNote: state.note,
        cents: state.cents,
      );
    } catch (e) {
      debugPrint('Error starting listening: $e');
    }
  }

  /// Handle pitch detection callback
  ///
  /// Stage 3: Called by pitch detector when a pitch is detected
  void _handlePitchDetection(double frequency) {
    if (!state.isListening) return;

    try {
      final noteData = _frequencyToNote(frequency);
      final cents = calculateCents(frequency);

      // Haptic feedback when reaching in-tune state (within ±5 cents)
      if (cents.abs() <= 5 && _previousCents.abs() > 5) {
        HapticFeedback.lightImpact();
      }
      _previousCents = cents;

      state = state.copyWith(
        frequency: frequency,
        note: noteData.displayName,
        cents: cents,
      );
    } catch (e) {
      debugPrint('Error handling pitch detection: $e');
    }
  }

  /// Stop listening to microphone
  Future<void> stopListening() async {
    if (!state.isListening) return;

    try {
      await _pitchDetector.stopListening();
      state = state.copyWith(isListening: false, cents: 0);
    } catch (e) {
      debugPrint('Error stopping listening: $e');
    }
  }

  /// Toggle listen/stop
  Future<void> toggleListening() async {
    if (state.isListening) {
      await stopListening();
    } else {
      await startListening();
    }
  }

  /// Set volume level
  void setVolume(double volume) {
    state = state.copyWith(volume: volume);
    if (state.isPlaying) {
      _toneGenerator.setVolume(volume);
    }
  }

  /// Convert frequency to musical note
  NoteData _frequencyToNote(double frequency) {
    // A4 = 440 Hz is our reference
    const referenceFrequency = 440.0;
    const referenceNoteIndex = 69; // MIDI note number for A4

    // Calculate MIDI note number from frequency
    final midiNote =
        referenceNoteIndex +
        12 * math.log(frequency / referenceFrequency) / math.ln10;
    final roundedMidiNote = midiNote.round();

    // Note names
    const noteNames = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];

    // Calculate note name and octave
    final noteIndex = roundedMidiNote % 12;
    final octave = (roundedMidiNote ~/ 12) - 1;
    final noteName = noteNames[noteIndex];

    // Calculate exact frequency for the rounded note
    final exactFrequency =
        referenceFrequency *
        math.pow(2, (roundedMidiNote - referenceNoteIndex) / 12);

    return NoteData(note: noteName, octave: octave, frequency: exactFrequency);
  }

  /// Calculate cents deviation from current frequency to nearest note
  int calculateCents(double frequency) {
    const referenceFrequency = 440.0;
    const referenceNoteIndex = 69;

    final midiNote =
        referenceNoteIndex +
        12 * math.log(frequency / referenceFrequency) / math.ln10;
    final roundedMidiNote = midiNote.round();
    final cents = ((midiNote - roundedMidiNote) * 100).round();

    return cents.clamp(-50, 50);
  }
}

/// NotifierProvider for tuner state management
final tunerProvider = NotifierProvider<TunerNotifier, TunerState>(() {
  return TunerNotifier();
});

/// Provider for current tuner mode
final tunerModeProvider = Provider<TunerMode>((ref) {
  return ref.watch(tunerProvider).mode;
});

/// Provider for current frequency
final tunerFrequencyProvider = Provider<double>((ref) {
  return ref.watch(tunerProvider).frequency;
});

/// Provider for current note
final tunerNoteProvider = Provider<String>((ref) {
  return ref.watch(tunerProvider).note;
});

/// Provider for cents deviation
final tunerCentsProvider = Provider<int>((ref) {
  return ref.watch(tunerProvider).cents;
});

/// Provider for playing state
final tunerIsPlayingProvider = Provider<bool>((ref) {
  return ref.watch(tunerProvider).isPlaying;
});

/// Provider for listening state
final tunerIsListeningProvider = Provider<bool>((ref) {
  return ref.watch(tunerProvider).isListening;
});
