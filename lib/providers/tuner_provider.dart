import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/instrument.dart';
import '../models/music_mode.dart';
import '../services/analytics_service.dart';
import '../services/audio/pitch_detector.dart';
import '../services/audio/tone_generator.dart';

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

  /// A4 calibration frequency (432-445 Hz)
  final double referenceA4;

  /// Whether haptic feedback is enabled
  final bool hapticEnabled;

  // === Post-MVP Features ===

  /// Available instruments (loaded from assets).
  final List<Instrument> instruments;

  /// Currently selected instrument.
  final Instrument? selectedInstrument;

  /// Currently selected tuning within the instrument.
  final Tuning? selectedTuning;

  /// Detection mode: auto (detect any note) or manual (target specific string).
  final DetectionMode detectionMode;

  /// In manual mode, the index of the target string (0-based).
  final int? manualTargetStringIndex;

  /// Custom tunings created by the user (in-memory only).
  final List<Tuning> customTunings;

  /// Whether stage mode is currently active (UI hidden, only large note shown).
  final bool stageModeActive;

  /// Whether stage mode is enabled (can be toggled in settings).
  final bool stageModeEnabled;

  /// Currently selected music mode/scale (for note ruler highlighting).
  final int musicModeIndex;

  const TunerState({
    this.mode = TunerMode.listen,
    this.frequency = 440.0,
    this.note = 'A4',
    this.cents = 0,
    this.isPlaying = false,
    this.isListening = false,
    this.volume = 0.5,
    this.referenceA4 = 440.0,
    this.hapticEnabled = true,
    this.instruments = const [],
    this.selectedInstrument,
    this.selectedTuning,
    this.detectionMode = DetectionMode.auto,
    this.manualTargetStringIndex,
    this.customTunings = const [],
    this.stageModeActive = false,
    this.stageModeEnabled = false,
    this.musicModeIndex = 0,
  });

  TunerState copyWith({
    TunerMode? mode,
    double? frequency,
    String? note,
    int? cents,
    bool? isPlaying,
    bool? isListening,
    double? volume,
    double? referenceA4,
    bool? hapticEnabled,
    List<Instrument>? instruments,
    Instrument? selectedInstrument,
    Tuning? selectedTuning,
    DetectionMode? detectionMode,
    int? manualTargetStringIndex,
    List<Tuning>? customTunings,
    bool? stageModeActive,
    bool? stageModeEnabled,
    int? musicModeIndex,
  }) {
    return TunerState(
      mode: mode ?? this.mode,
      frequency: frequency ?? this.frequency,
      note: note ?? this.note,
      cents: cents ?? this.cents,
      isPlaying: isPlaying ?? this.isPlaying,
      isListening: isListening ?? this.isListening,
      volume: volume ?? this.volume,
      referenceA4: referenceA4 ?? this.referenceA4,
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      instruments: instruments ?? this.instruments,
      selectedInstrument: selectedInstrument ?? this.selectedInstrument,
      selectedTuning: selectedTuning ?? this.selectedTuning,
      detectionMode: detectionMode ?? this.detectionMode,
      manualTargetStringIndex:
          manualTargetStringIndex ?? this.manualTargetStringIndex,
      customTunings: customTunings ?? this.customTunings,
      stageModeActive: stageModeActive ?? this.stageModeActive,
      stageModeEnabled: stageModeEnabled ?? this.stageModeEnabled,
      musicModeIndex: musicModeIndex ?? this.musicModeIndex,
    );
  }

  @override
  String toString() {
    return 'TunerState(mode: $mode, frequency: ${frequency.toStringAsFixed(1)} Hz, '
        'note: $note, cents: $cents, isPlaying: $isPlaying, isListening: $isListening)';
  }

  /// Create initial state (instruments loaded asynchronously in build).
  static TunerState initial() => const TunerState();

  /// Get the target note for manual mode detection.
  /// Returns null if in auto mode or no string selected.
  String? get manualTargetNote {
    if (detectionMode != DetectionMode.manual) return null;
    if (manualTargetStringIndex == null) return null;
    if (selectedTuning == null) return null;
    if (manualTargetStringIndex! >= selectedTuning!.notes.length) return null;
    return selectedTuning!.notes[manualTargetStringIndex!];
  }

  /// Get all available tunings for the selected instrument (including custom).
  List<Tuning> get availableTunings {
    if (selectedInstrument == null) return [];
    return [...selectedInstrument!.tunings, ...customTunings];
  }
}

/// Notifier for tuner state management using Riverpod
class TunerNotifier extends Notifier<TunerState> {
  final _toneGenerator = ToneGenerator();
  final _pitchDetector = PitchDetector();
  int _previousCents = 0;
  bool _instrumentsLoaded = false;

  @override
  TunerState build() {
    // Defer loading instruments using microtask to avoid blocking first frame
    // This prevents the 57 frame skips during navigation
    // Using Future.microtask instead of addPostFrameCallback for test compatibility
    Future.microtask(_loadInstrumentsFromAssets);

    // Auto-dispose resources when provider is no longer watched
    ref.onDispose(() {
      _toneGenerator.dispose();
      _pitchDetector.dispose();
    });

    return TunerState.initial();
  }

  /// Load instruments from assets JSON.
  Future<void> _loadInstrumentsFromAssets() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/tunings.json');
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final instrumentsList = json['instruments'] as List<dynamic>;
      final instruments = instrumentsList
          .map((i) => Instrument.fromJson(i as Map<String, dynamic>))
          .toList();

      if (instruments.isNotEmpty && !_instrumentsLoaded) {
        _instrumentsLoaded = true;
        final defaultInstrument = instruments.first;
        final defaultTuning = defaultInstrument.defaultTuning;

        state = state.copyWith(
          instruments: instruments,
          selectedInstrument: defaultInstrument,
          selectedTuning: defaultTuning,
        );
      }
    } catch (e) {
      debugPrint('Error loading instruments from assets: $e');
      // Fallback: state remains with empty instruments list
    }
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

    // Update playing tone in real-time if in Generate mode
    if (state.mode == TunerMode.generate && state.isPlaying) {
      _toneGenerator.setFrequency(clampedFrequency);
    }
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
      // Log analytics event (fire-and-forget)
      unawaited(AnalyticsService.logTunerUsed(
        mode: 'generate',
        targetNote: state.note,
      ));
    }
  }

  /// Start listening to microphone (Listen mode)
  ///
  /// Stage 3: Real pitch detection using YIN algorithm
  bool _isStarting = false;

  Future<void> startListening() async {
    if (state.mode != TunerMode.listen) return;
    if (state.isListening || _isStarting) return;

    _isStarting = true;
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

      // Log analytics event (fire-and-forget)
      unawaited(AnalyticsService.logTunerUsed(
        mode: 'listen',
        detectedNote: state.note,
        cents: state.cents,
      ));
    } catch (e) {
      debugPrint('Error starting listening: $e');
    } finally {
      _isStarting = false;
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

      // Enhanced haptic feedback with precision levels
      if (state.hapticEnabled) {
        // Perfect tune (±1 cent) - strong confirmation
        if (cents.abs() <= 1 && _previousCents.abs() > 1) {
          HapticFeedback.mediumImpact();
        }
        // Near tune (±5 cents) - gentle confirmation
        else if (cents.abs() <= 5 && _previousCents.abs() > 5) {
          HapticFeedback.lightImpact();
        }
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

  /// Set A4 reference frequency (432-445 Hz)
  void setReferenceA4(double frequency) {
    state = state.copyWith(referenceA4: frequency.clamp(432.0, 445.0));
  }

  /// Toggle haptic feedback
  void toggleHapticFeedback() {
    state = state.copyWith(hapticEnabled: !state.hapticEnabled);
  }

  /// Trigger haptic feedback if enabled
  void triggerHaptic(String type) {
    if (!state.hapticEnabled) return;

    switch (type) {
      case 'light':
        HapticFeedback.lightImpact();
      case 'medium':
        HapticFeedback.mediumImpact();
      case 'heavy':
        HapticFeedback.heavyImpact();
      case 'selection':
        HapticFeedback.selectionClick();
    }
  }

  /// Convert frequency to musical note
  NoteData _frequencyToNote(double frequency) {
    // A4 reference is configurable
    final referenceFrequency = state.referenceA4;
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
    final referenceFrequency = state.referenceA4;
    const referenceNoteIndex = 69;

    final midiNote =
        referenceNoteIndex +
        12 * math.log(frequency / referenceFrequency) / math.ln10;
    final roundedMidiNote = midiNote.round();
    final cents = ((midiNote - roundedMidiNote) * 100).round();

    return cents.clamp(-50, 50);
  }

  // === Post-MVP: Instrument & Tuning Selection ===

  /// Select an instrument and its default tuning.
  void selectInstrument(Instrument instrument) {
    final defaultTuning = instrument.defaultTuning;
    state = state.copyWith(
      selectedInstrument: instrument,
      selectedTuning: defaultTuning,
      manualTargetStringIndex: null, // Reset manual selection
    );
  }

  /// Select a specific tuning for the current instrument.
  void selectTuning(Tuning tuning) {
    state = state.copyWith(
      selectedTuning: tuning,
      manualTargetStringIndex: null, // Reset manual selection
    );
  }

  // === Post-MVP: Detection Mode ===

  /// Set detection mode (auto or manual).
  void setDetectionMode(DetectionMode mode) {
    state = state.copyWith(
      detectionMode: mode,
      manualTargetStringIndex: mode == DetectionMode.auto ? null : state.manualTargetStringIndex,
    );
  }

  /// Toggle between auto and manual detection modes.
  void toggleDetectionMode() {
    setDetectionMode(
      state.detectionMode == DetectionMode.auto
          ? DetectionMode.manual
          : DetectionMode.auto,
    );
  }

  /// Set the target string index for manual mode.
  /// Also updates frequency to match the selected note so dial aligns.
  void setManualTargetStringIndex(int index) {
    if (index < 0 || state.selectedTuning == null) {
      debugPrint('⚠️ setManualTargetStringIndex: invalid index or no tuning');
      return;
    }
    
    final tuning = state.selectedTuning!;
    if (index >= tuning.notes.length) {
      debugPrint('⚠️ setManualTargetStringIndex: index $index >= notes length ${tuning.notes.length}');
      return;
    }
    
    // Get the note name (e.g., "E2")
    final noteName = tuning.notes[index];
    debugPrint('🎵 setManualTargetStringIndex($index): noteName=$noteName');
    
    // Calculate frequency from note name
    final targetFrequency = _parseNoteNameToFrequency(noteName);
    debugPrint('🎵 Calculated frequency: $targetFrequency Hz');
    
    state = state.copyWith(
      manualTargetStringIndex: index,
      frequency: targetFrequency,
      note: noteName,
      cents: 0,
    );
    
    debugPrint('🎵 State updated: manualTargetStringIndex=$index, note=$noteName, freq=$targetFrequency');
  }

  /// Set target note directly by chromatic index (0-11, C-B)
  /// Used when user taps on the dial ring
  void setTargetNoteByIndex(int chromaticIndex) {
    // Find the frequency for this chromatic note in the current octave
    const noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final noteName = noteNames[chromaticIndex % 12];
    
    // Default to 4th octave for simplicity
    final fullNoteName = '${noteName}4';
    final frequency = _parseNoteNameToFrequency(fullNoteName);
    
    debugPrint('🎵 setTargetNoteByIndex($chromaticIndex): noteName=$noteName, fullNoteName=$fullNoteName, freq=$frequency');
    
    state = state.copyWith(
      note: fullNoteName,
      frequency: frequency,
      cents: 0,
    );
    
    debugPrint('🎵 State updated: note=${state.note}, freq=${state.frequency}');
  }

  /// Parse note name (e.g., "E2", "A4", "C#3") to frequency in Hz
  double _parseNoteNameToFrequency(String noteName) {
    // Extract note name and octave
    final match = RegExp(r'^([A-G]#?)(\d+)$').firstMatch(noteName);
    if (match == null) return 440.0; // Default to A4
    
    final note = match.group(1)!;
    final octave = int.parse(match.group(2)!);
    
    // Note to semitone offset from A4
    const noteOffsets = {
      'C': -9, 'C#': -8, 'D': -7, 'D#': -6, 'E': -5,
      'F': -4, 'F#': -3, 'G': -2, 'G#': -1, 'A': 0, 'A#': 1, 'B': 2,
    };
    
    final semitoneOffset = noteOffsets[note] ?? 0;
    final totalSemitones = semitoneOffset + (octave - 4) * 12;
    
    // A4 = 440 Hz reference
    return state.referenceA4 * math.pow(2, totalSemitones / 12);
  }

  // === Post-MVP: Custom Tunings ===

  /// Add a custom tuning to the in-memory list.
  void addCustomTuning(Tuning tuning) {
    state = state.copyWith(
      customTunings: [...state.customTunings, tuning],
    );
  }

  /// Remove a custom tuning by ID.
  void removeCustomTuning(String tuningId) {
    state = state.copyWith(
      customTunings: state.customTunings.where((t) => t.id != tuningId).toList(),
    );
  }

  // === Post-MVP: Stage Mode ===

  /// Toggle whether stage mode is enabled.
  void toggleStageModeEnabled() {
    state = state.copyWith(
      stageModeEnabled: !state.stageModeEnabled,
      stageModeActive: false, // Deactivate when disabling
    );
  }

  /// Activate or deactivate stage mode overlay.
  void setStageModeActive({required bool active}) {
    state = state.copyWith(stageModeActive: active);
  }

  /// Exit stage mode (convenience method).
  void exitStageMode() {
    state = state.copyWith(stageModeActive: false);
  }

  // === Post-MVP: Music Modes (Scales) ===

  /// Cycle to next music mode/scale
  void cycleMusicMode() {
    final nextIndex = (state.musicModeIndex + 1) % allMusicModes.length;
    state = state.copyWith(musicModeIndex: nextIndex);
    
    // Haptic feedback
    if (state.hapticEnabled) {
      HapticFeedback.mediumImpact();
    }
  }

  /// Set specific music mode
  void setMusicMode(int index) {
    if (index >= 0 && index < allMusicModes.length) {
      state = state.copyWith(musicModeIndex: index);
    }
  }

  /// Get current music mode
  MusicMode get currentMusicMode => allMusicModes[state.musicModeIndex];

  /// Check if a note index (0-11) is in the current scale
  bool isNoteInScale(int noteIndex) {
    return currentMusicMode.containsNote(noteIndex);
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

// === Post-MVP Derived Providers ===

/// Provider for selected instrument.
final selectedInstrumentProvider = Provider<Instrument?>((ref) {
  return ref.watch(tunerProvider).selectedInstrument;
});

/// Provider for selected tuning.
final selectedTuningProvider = Provider<Tuning?>((ref) {
  return ref.watch(tunerProvider).selectedTuning;
});

/// Provider for detection mode.
final detectionModeProvider = Provider<DetectionMode>((ref) {
  return ref.watch(tunerProvider).detectionMode;
});

/// Provider for manual target string index.
final manualTargetStringIndexProvider = Provider<int?>((ref) {
  return ref.watch(tunerProvider).manualTargetStringIndex;
});

/// Provider for custom tunings list.
final customTuningsProvider = Provider<List<Tuning>>((ref) {
  return ref.watch(tunerProvider).customTunings;
});

/// Provider for stage mode active state.
final stageModeActiveProvider = Provider<bool>((ref) {
  return ref.watch(tunerProvider).stageModeActive;
});

/// Provider for stage mode enabled state.
final stageModeEnabledProvider = Provider<bool>((ref) {
  return ref.watch(tunerProvider).stageModeEnabled;
});
