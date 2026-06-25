import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/instrument.dart';
import '../models/music_mode.dart';
import '../models/tuner_preset.dart';
import '../repositories/tuner_preset_repository.dart';
import '../services/analytics_service.dart';
import '../services/audio/pitch_analysis.dart';
import '../services/audio/pitch_detector.dart';
import '../services/audio/tone_generator.dart';
import '../services/tuner_preferences.dart';

enum TunerMode { generate, listen }

class NoteData {

  const NoteData({
    required this.note,
    required this.octave,
    required this.frequency,
  });
  final String note;
  final int octave;
  final double frequency;

  String get displayName => '$note$octave';

  @override
  String toString() => displayName;
}

const Object _notSet = Object();

class TunerState {

  const TunerState({
    this.mode = TunerMode.listen,
    this.frequency = 440,
    this.note = 'A4',
    this.cents = 0,
    this.isPlaying = false,
    this.isListening = false,
    this.isStarting = false,
    this.volume = 0.5,
    this.referenceA4 = 440,
    this.hapticEnabled = true,
    this.permissionState = TunerPermissionState.notRequested,
    this.signalState = TunerSignalState.idle,
    this.confidence = 0,
    this.inputLevelDb = -120,
    this.errorMessage,
    this.centsTolerance = 5,
    this.sensitivity = 50,
    this.droneEnabled = false,
    this.recentPresetIds = const [],
    this.instruments = const [],
    this.selectedInstrument,
    this.selectedTuning,
    this.detectionMode = DetectionMode.auto,
    this.manualTargetStringIndex,
    this.customTunings = const [],
    this.customTuningScopes = const {},
    this.stageModeActive = false,
    this.stageModeEnabled = false,
    this.musicModeIndex = 0,
  });
  final TunerMode mode;
  final double frequency;
  final String note;
  final int cents;
  final bool isPlaying;
  final bool isListening;
  final bool isStarting;
  final double volume;
  final double referenceA4;
  final bool hapticEnabled;
  final TunerPermissionState permissionState;
  final TunerSignalState signalState;
  final double confidence;
  final double inputLevelDb;
  final String? errorMessage;
  final int centsTolerance;
  final double sensitivity;
  final bool droneEnabled;
  final List<String> recentPresetIds;
  final List<Instrument> instruments;
  final Instrument? selectedInstrument;
  final Tuning? selectedTuning;
  final DetectionMode detectionMode;
  final int? manualTargetStringIndex;
  final List<Tuning> customTunings;
  final Map<String, TunerPresetScope> customTuningScopes;
  final bool stageModeActive;
  final bool stageModeEnabled;
  final int musicModeIndex;

  bool get hasValidPitch =>
      signalState == TunerSignalState.detected ||
      signalState == TunerSignalState.inTune;
  bool get isInTune => signalState == TunerSignalState.inTune;

  TunerState copyWith({
    TunerMode? mode,
    double? frequency,
    String? note,
    int? cents,
    bool? isPlaying,
    bool? isListening,
    bool? isStarting,
    double? volume,
    double? referenceA4,
    bool? hapticEnabled,
    TunerPermissionState? permissionState,
    TunerSignalState? signalState,
    double? confidence,
    double? inputLevelDb,
    Object? errorMessage = _notSet,
    int? centsTolerance,
    double? sensitivity,
    bool? droneEnabled,
    List<String>? recentPresetIds,
    List<Instrument>? instruments,
    Object? selectedInstrument = _notSet,
    Object? selectedTuning = _notSet,
    DetectionMode? detectionMode,
    Object? manualTargetStringIndex = _notSet,
    List<Tuning>? customTunings,
    Map<String, TunerPresetScope>? customTuningScopes,
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
      isStarting: isStarting ?? this.isStarting,
      volume: volume ?? this.volume,
      referenceA4: referenceA4 ?? this.referenceA4,
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      permissionState: permissionState ?? this.permissionState,
      signalState: signalState ?? this.signalState,
      confidence: confidence ?? this.confidence,
      inputLevelDb: inputLevelDb ?? this.inputLevelDb,
      errorMessage: errorMessage == _notSet
          ? this.errorMessage
          : errorMessage as String?,
      centsTolerance: centsTolerance ?? this.centsTolerance,
      sensitivity: sensitivity ?? this.sensitivity,
      droneEnabled: droneEnabled ?? this.droneEnabled,
      recentPresetIds: recentPresetIds ?? this.recentPresetIds,
      instruments: instruments ?? this.instruments,
      selectedInstrument: selectedInstrument == _notSet
          ? this.selectedInstrument
          : selectedInstrument as Instrument?,
      selectedTuning: selectedTuning == _notSet
          ? this.selectedTuning
          : selectedTuning as Tuning?,
      detectionMode: detectionMode ?? this.detectionMode,
      manualTargetStringIndex: manualTargetStringIndex == _notSet
          ? this.manualTargetStringIndex
          : manualTargetStringIndex as int?,
      customTunings: customTunings ?? this.customTunings,
      customTuningScopes: customTuningScopes ?? this.customTuningScopes,
      stageModeActive: stageModeActive ?? this.stageModeActive,
      stageModeEnabled: stageModeEnabled ?? this.stageModeEnabled,
      musicModeIndex: musicModeIndex ?? this.musicModeIndex,
    );
  }

  static TunerState initial() => const TunerState();

  String? get manualTargetNote {
    final index = manualTargetStringIndex;
    final tuning = selectedTuning;
    if (detectionMode != DetectionMode.manual ||
        index == null ||
        tuning == null) {
      return null;
    }
    if (index < 0 || index >= tuning.notes.length) return null;
    return tuning.notes[index];
  }

  List<Tuning> get availableTunings {
    final instrument = selectedInstrument;
    if (instrument == null) return customTunings;
    return [...instrument.tunings, ...customTunings];
  }

  String? get selectedPresetId {
    final instrument = selectedInstrument;
    final tuning = selectedTuning;
    if (tuning == null) return null;
    if (customTunings.any((value) => value.id == tuning.id)) return tuning.id;
    if (instrument == null) return tuning.id;
    return '${instrument.id}:${tuning.id}';
  }

  TunerPresetScope? get selectedPresetScope {
    final tuning = selectedTuning;
    if (tuning == null) return null;
    return customTuningScopes[tuning.id];
  }

  @override
  String toString() =>
      'TunerState(mode: $mode, frequency: ${frequency.toStringAsFixed(1)} Hz, '
      'note: $note, cents: $cents, signal: $signalState)';
}

class TunerNotifier extends Notifier<TunerState> {

  TunerNotifier({
    ToneGenerator? toneGenerator,
    PitchDetector? pitchDetector,
    TunerPreferences? preferences,
    TunerPresetRepository? presetRepository,
  }) : _toneGenerator = toneGenerator ?? ToneGenerator(),
       _pitchDetector = pitchDetector ?? PitchDetector(),
       _preferences = preferences ?? TunerPreferences(),
       _presetRepository = presetRepository ?? TunerPresetRepository();
  final ToneGenerator _toneGenerator;
  final PitchDetector _pitchDetector;
  final TunerPreferences _preferences;
  final TunerPresetRepository _presetRepository;

  Timer? _toneTimer;
  bool _instrumentsLoaded = false;
  double? _smoothedCents;
  String? _candidateNote;
  int _candidateNoteCount = 0;
  int _insideToleranceCount = 0;
  int _outsideToleranceCount = 0;
  bool _inTuneEventSent = false;
  String? _pendingPresetId;
  final Map<String, TunerPreset> _customPresetsById = {};

  @override
  TunerState build() {
    _pitchDetector.onSample = _handlePitchSample;
    Future.microtask(_restorePreferences);
    Future.microtask(_loadInstrumentsAndPresets);
    ref.onDispose(() {
      _toneTimer?.cancel();
      unawaited(_toneGenerator.dispose());
      unawaited(_pitchDetector.dispose());
    });
    return TunerState.initial();
  }

  Future<void> _restorePreferences() async {
    try {
      final values = await _preferences.load();
      final modeName = values['mode'] as String?;
      final restoredMode = TunerMode.values.where(
        (mode) => mode.name == modeName,
      );
      if (!ref.mounted) return;
      final sensitivity = (values['sensitivity'] as num?)?.toDouble() ?? 50;
      _pitchDetector.setSensitivity(sensitivity);
      state = state.copyWith(
        mode: restoredMode.isEmpty ? state.mode : restoredMode.first,
        referenceA4: ((values['referenceHz'] as num?)?.toDouble() ?? 440).clamp(
          415.0,
          466.0,
        ),
        volume: ((values['volume'] as num?)?.toDouble() ?? 0.5).clamp(0.0, 1.0),
        centsTolerance: ((values['centsTolerance'] as num?)?.toInt() ?? 5)
            .clamp(1, 20),
        sensitivity: sensitivity.clamp(0.0, 100.0),
        droneEnabled: values['droneEnabled'] as bool? ?? false,
        recentPresetIds:
            (values['recentPresetIds'] as List<String>?) ?? const [],
      );
    } catch (error) {
      debugPrint('Unable to restore tuner preferences: $error');
    }
  }

  Future<void> _loadInstrumentsAndPresets() async {
    try {
      final results = await Future.wait<Object>([
        rootBundle.loadString('assets/data/tunings.json'),
        _presetRepository.loadLocal(),
      ]);
      final json = jsonDecode(results[0] as String) as Map<String, dynamic>;
      final instruments = (json['instruments'] as List<dynamic>)
          .map((value) => Instrument.fromJson(value as Map<String, dynamic>))
          .toList();
      final customPresets = results[1] as List<TunerPreset>;
      if (!ref.mounted) return;
      final customTunings = customPresets
          .map(
            (preset) => Tuning(
              id: preset.id,
              name: preset.name,
              notes: preset.tuningNotes
                  .map((note) => note.displayName)
                  .toList(),
            ),
          )
          .toList();
      final customScopes = <String, TunerPresetScope>{
        for (final preset in customPresets) preset.id: preset.scope,
      };
      _customPresetsById.addEntries(
        customPresets.map((preset) => MapEntry(preset.id, preset)),
      );
      if (instruments.isEmpty || _instrumentsLoaded) return;
      _instrumentsLoaded = true;

      final preferences = await _preferences.load();
      final selectedId = preferences['presetId'] as String?;
      Instrument selectedInstrument = instruments.first;
      Tuning selectedTuning = selectedInstrument.defaultTuning;
      if (selectedId != null && selectedId.contains(':')) {
        final parts = selectedId.split(':');
        selectedInstrument = instruments.firstWhere(
          (instrument) => instrument.id == parts.first,
          orElse: () => selectedInstrument,
        );
        selectedTuning = selectedInstrument.tunings.firstWhere(
          (tuning) => tuning.id == parts.last,
          orElse: () => selectedInstrument.defaultTuning,
        );
      } else if (selectedId != null) {
        final customIndex = customTunings.indexWhere(
          (tuning) => tuning.id == selectedId,
        );
        if (customIndex >= 0) {
          selectedTuning = customTunings[customIndex];
        } else {
          _pendingPresetId = selectedId;
        }
      }
      state = state.copyWith(
        instruments: instruments,
        selectedInstrument: selectedInstrument,
        selectedTuning: selectedTuning,
        customTunings: customTunings,
        customTuningScopes: customScopes,
      );
      final pendingPresetId = _pendingPresetId;
      if (pendingPresetId != null) selectPresetById(pendingPresetId);
      unawaited(loadContextPresets());
    } catch (error) {
      debugPrint('Unable to load tuner presets: $error');
      if (!ref.mounted) return;
      state = state.copyWith(
        errorMessage: 'Tuner presets could not be loaded.',
      );
    }
  }

  Future<void> setMode(TunerMode mode) async {
    if (state.mode == mode) return;
    await stopAll();
    state = state.copyWith(
      mode: mode,
      signalState: TunerSignalState.idle,
      errorMessage: null,
    );
    unawaited(_preferences.saveMode(mode.name));
  }

  void updateFrequency(double frequency) {
    final value = frequency.clamp(20.0, 2000.0);
    final note = frequencyToNote(value);
    state = state.copyWith(frequency: value, note: note.displayName, cents: 0);
    if (state.isPlaying) _toneGenerator.setFrequency(value);
  }

  void setFrequency(double frequency) => updateFrequency(frequency);

  void setToneNote(String note, int octave) {
    final frequency = TunerNoteMath.frequencyForNote(
      '$note$octave',
      state.referenceA4,
    );
    updateFrequency(frequency);
  }

  Future<void> startPlaying() async {
    if (state.mode != TunerMode.generate ||
        state.isPlaying ||
        state.isStarting) {
      return;
    }
    _toneTimer?.cancel();
    state = state.copyWith(isStarting: true, errorMessage: null);
    try {
      await _toneGenerator.startTone(state.frequency, state.volume);
      state = state.copyWith(isPlaying: true, isStarting: false);
      unawaited(
        AnalyticsService.logTunerEvent('tuner_tone_started', {
          'drone': state.droneEnabled ? 1 : 0,
        }),
      );
      if (!state.droneEnabled) {
        _toneTimer = Timer(const Duration(seconds: 2), stopPlaying);
      }
    } catch (error) {
      state = state.copyWith(
        isStarting: false,
        errorMessage: 'The reference tone could not be started.',
      );
    }
  }

  Future<void> stopPlaying() async {
    _toneTimer?.cancel();
    _toneTimer = null;
    if (!state.isPlaying && !_toneGenerator.isPlaying) return;
    await _toneGenerator.stopTone();
    state = state.copyWith(isPlaying: false, isStarting: false);
    unawaited(AnalyticsService.logTunerEvent('tuner_tone_stopped'));
  }

  Future<void> togglePlaying() =>
      state.isPlaying ? stopPlaying() : startPlaying();

  Future<void> startListening() async {
    if (state.mode != TunerMode.listen ||
        state.isListening ||
        state.isStarting) {
      return;
    }
    state = state.copyWith(isStarting: true, errorMessage: null);
    var permission = await _pitchDetector.permissionStatus();
    final requestedPermission = permission != TunerPermissionState.granted;
    if (requestedPermission &&
        permission != TunerPermissionState.permanentlyDenied &&
        permission != TunerPermissionState.unavailable) {
      unawaited(AnalyticsService.logTunerEvent('tuner_permission_prompted'));
      permission = await _pitchDetector.requestPermission();
    }
    state = state.copyWith(permissionState: permission);
    if (permission != TunerPermissionState.granted) {
      state = state.copyWith(
        isStarting: false,
        errorMessage: _permissionError(permission),
      );
      unawaited(
        AnalyticsService.logTunerEvent('tuner_permission_denied', {
          'state': permission.name,
        }),
      );
      return;
    }

    if (requestedPermission) {
      unawaited(AnalyticsService.logTunerEvent('tuner_permission_granted'));
    }
    try {
      _resetStability();
      _applyDetectionRange();
      await _pitchDetector.startListening();
      state = state.copyWith(
        isListening: true,
        isStarting: false,
        signalState: TunerSignalState.noSignal,
        errorMessage: null,
      );
      unawaited(AnalyticsService.logTunerEvent('tuner_listen_started'));
    } catch (error) {
      state = state.copyWith(
        isListening: false,
        isStarting: false,
        signalState: TunerSignalState.idle,
        errorMessage: 'The microphone is unavailable or already in use.',
      );
    }
  }

  String _permissionError(TunerPermissionState permission) {
    return switch (permission) {
      TunerPermissionState.permanentlyDenied =>
        'Microphone access is blocked. Open system settings to enable it.',
      TunerPermissionState.unavailable =>
        'Microphone capture is unavailable on this device or browser.',
      _ => 'Microphone access is required for Listen mode.',
    };
  }

  void _handlePitchSample(PitchSample sample) {
    if (!state.isListening) return;
    final frequency = sample.frequencyHz;
    if (frequency == null || sample.signalState != TunerSignalState.detected) {
      _insideToleranceCount = 0;
      _outsideToleranceCount++;
      state = state.copyWith(
        signalState: sample.signalState,
        confidence: sample.confidence,
        inputLevelDb: sample.rmsDb,
      );
      return;
    }

    final manualTarget = state.manualTargetNote;
    final detectedNote = frequencyToNote(frequency);
    final displayNote =
        manualTarget ?? _stableDetectedNote(detectedNote.displayName);
    final rawCents = manualTarget == null
        ? TunerNoteMath.centsFromNearestNote(frequency, state.referenceA4)
        : 1200 *
              math.log(
                frequency /
                    TunerNoteMath.frequencyForNote(
                      manualTarget,
                      state.referenceA4,
                    ),
              ) /
              math.ln2;
    _smoothedCents = _smoothedCents == null
        ? rawCents
        : (_smoothedCents! * 0.65) + (rawCents * 0.35);
    final cents = _smoothedCents!.round().clamp(-50, 50);
    final inside = cents.abs() <= state.centsTolerance;

    if (inside) {
      _insideToleranceCount++;
      _outsideToleranceCount = 0;
    } else if (cents.abs() > state.centsTolerance + 2) {
      _outsideToleranceCount++;
      _insideToleranceCount = 0;
    }

    var signalState = TunerSignalState.detected;
    if (state.isInTune) {
      signalState = _outsideToleranceCount >= 5
          ? TunerSignalState.detected
          : TunerSignalState.inTune;
    } else if (_insideToleranceCount >= 6) {
      signalState = TunerSignalState.inTune;
    }

    if (signalState == TunerSignalState.inTune && !state.isInTune) {
      if (state.hapticEnabled) HapticFeedback.mediumImpact();
      if (!_inTuneEventSent) {
        _inTuneEventSent = true;
        unawaited(
          AnalyticsService.logTunerEvent('tuner_in_tune_reached', {
            'note': displayNote,
          }),
        );
      }
    }

    state = state.copyWith(
      frequency: frequency,
      note: displayNote,
      cents: cents,
      signalState: signalState,
      confidence: sample.confidence,
      inputLevelDb: sample.rmsDb,
    );
  }

  String _stableDetectedNote(String detected) {
    if (detected == state.note) {
      _candidateNote = null;
      _candidateNoteCount = 0;
      return detected;
    }
    if (_candidateNote == detected) {
      _candidateNoteCount++;
    } else {
      _candidateNote = detected;
      _candidateNoteCount = 1;
    }
    return _candidateNoteCount >= 2 ? detected : state.note;
  }

  Future<void> stopListening() async {
    if (!state.isListening && !_pitchDetector.isListening) return;
    await _pitchDetector.stopListening();
    _resetStability();
    state = state.copyWith(
      isListening: false,
      isStarting: false,
      signalState: TunerSignalState.idle,
      cents: 0,
      confidence: 0,
      inputLevelDb: -120,
    );
    unawaited(AnalyticsService.logTunerEvent('tuner_listen_stopped'));
  }

  Future<void> toggleListening() =>
      state.isListening ? stopListening() : startListening();

  Future<void> stopAll() async {
    await Future.wait<void>([stopPlaying(), stopListening()]);
  }

  Future<void> openPermissionSettings() async {
    await _pitchDetector.openPermissionSettings();
  }

  void _resetStability() {
    _smoothedCents = null;
    _candidateNote = null;
    _candidateNoteCount = 0;
    _insideToleranceCount = 0;
    _outsideToleranceCount = 0;
    _inTuneEventSent = false;
  }

  void setVolume(double volume) {
    final value = volume.clamp(0.0, 1.0);
    state = state.copyWith(volume: value);
    _toneGenerator.setVolume(value);
    unawaited(_preferences.saveVolume(value));
  }

  void setReferenceA4(double frequency) {
    final value = frequency.clamp(415.0, 466.0);
    state = state.copyWith(referenceA4: value);
    if (state.mode == TunerMode.generate) {
      try {
        final updated = TunerNoteMath.frequencyForNote(state.note, value);
        state = state.copyWith(frequency: updated);
        _toneGenerator.setFrequency(updated);
      } on FormatException {
        // Keep the current tone when no valid note is selected.
      }
    }
    unawaited(_preferences.saveReferenceHz(value));
  }

  void setCentsTolerance(double value) {
    final tolerance = value.round().clamp(1, 20);
    state = state.copyWith(centsTolerance: tolerance);
    unawaited(_preferences.saveTolerance(tolerance));
  }

  void setSensitivity(double value) {
    final sensitivity = value.clamp(0.0, 100.0);
    state = state.copyWith(sensitivity: sensitivity);
    _pitchDetector.setSensitivity(sensitivity);
    unawaited(_preferences.saveSensitivity(sensitivity));
  }

  void toggleDrone() {
    final enabled = !state.droneEnabled;
    state = state.copyWith(droneEnabled: enabled);
    unawaited(_preferences.saveDroneEnabled(value: enabled));
    if (!enabled && state.isPlaying) {
      _toneTimer?.cancel();
      _toneTimer = Timer(const Duration(seconds: 2), stopPlaying);
    }
  }

  void toggleHapticFeedback() {
    state = state.copyWith(hapticEnabled: !state.hapticEnabled);
  }

  void triggerHaptic(String type) {
    if (!state.hapticEnabled) return;
    switch (type) {
      case 'medium':
        HapticFeedback.mediumImpact();
      case 'heavy':
        HapticFeedback.heavyImpact();
      case 'selection':
        HapticFeedback.selectionClick();
      default:
        HapticFeedback.lightImpact();
    }
  }

  NoteData frequencyToNote(double frequency) {
    final midi = TunerNoteMath.midiForFrequency(frequency, state.referenceA4);
    final display = TunerNoteMath.noteNameForMidi(midi);
    final match = RegExp(r'^([A-G]#?)(-?\d+)$').firstMatch(display)!;
    return NoteData(
      note: match.group(1)!,
      octave: int.parse(match.group(2)!),
      frequency: TunerNoteMath.frequencyForMidi(midi, state.referenceA4),
    );
  }

  int calculateCents(double frequency) {
    return TunerNoteMath.centsFromNearestNote(
      frequency,
      state.referenceA4,
    ).round().clamp(-50, 50);
  }

  void selectInstrument(Instrument instrument) {
    final tuning = instrument.defaultTuning;
    state = state.copyWith(
      selectedInstrument: instrument,
      selectedTuning: tuning,
      manualTargetStringIndex: null,
    );
    _applyDetectionRange();
    _rememberPreset(instrument, tuning);
  }

  /// Narrow pitch detection to the selected tuning's note span (with margins)
  /// so bass octaves and high-string overtones don't pull the estimate. Tunings
  /// with fewer than two notes (chromatic/voice) keep the full default window.
  void _applyDetectionRange() {
    final notes = state.selectedTuning?.notes ?? const <String>[];
    if (notes.length < 2) {
      _pitchDetector.setFrequencyRange(35, 2100);
      return;
    }
    try {
      var lowest = double.infinity;
      var highest = 0.0;
      for (final note in notes) {
        final freq = TunerNoteMath.frequencyForNote(note, state.referenceA4);
        if (freq < lowest) lowest = freq;
        if (freq > highest) highest = freq;
      }
      // ponytail: −3 / +12 semitone margins are a comfort knob; widen if real
      // instruments clip at the edges.
      _pitchDetector.setFrequencyRange(
        lowest * math.pow(2, -3 / 12),
        highest * 2,
      );
    } catch (_) {
      _pitchDetector.setFrequencyRange(35, 2100);
    }
  }

  void selectTuning(Tuning tuning) {
    final preset = _customPresetsById[tuning.id];
    state = state.copyWith(
      selectedTuning: tuning,
      manualTargetStringIndex: null,
      referenceA4: preset?.referenceHz,
      centsTolerance: preset?.centsTolerance,
    );
    if (preset != null) {
      unawaited(_preferences.saveReferenceHz(preset.referenceHz));
      unawaited(_preferences.saveTolerance(preset.centsTolerance));
    }
    _applyDetectionRange();
    final instrument = state.selectedInstrument;
    if (instrument != null) _rememberPreset(instrument, tuning);
  }

  void _rememberPreset(Instrument instrument, Tuning tuning) {
    final id = _customPresetsById.containsKey(tuning.id)
        ? tuning.id
        : '${instrument.id}:${tuning.id}';
    final recent = <String>[
      id,
      ...state.recentPresetIds.where((value) => value != id),
    ];
    state = state.copyWith(recentPresetIds: recent.take(10).toList());
    unawaited(_preferences.saveSelectedPreset(id));
    unawaited(
      AnalyticsService.logTunerEvent('tuner_preset_selected', {
        'preset_id': id,
      }),
    );
  }

  bool selectPresetById(String presetId) {
    _pendingPresetId = presetId;
    if (presetId.contains(':')) {
      final parts = presetId.split(':');
      for (final instrument in state.instruments) {
        if (instrument.id != parts.first) continue;
        for (final tuning in instrument.tunings) {
          if (tuning.id == parts.last) {
            _pendingPresetId = null;
            state = state.copyWith(
              selectedInstrument: instrument,
              selectedTuning: tuning,
              manualTargetStringIndex: null,
            );
            _rememberPreset(instrument, tuning);
            return true;
          }
        }
      }
    } else {
      for (final tuning in state.customTunings) {
        if (tuning.id == presetId) {
          _pendingPresetId = null;
          selectTuning(tuning);
          return true;
        }
      }
    }
    return false;
  }

  Future<void> loadContextPresets({String? bandId, String? songId}) async {
    try {
      final presets = await _presetRepository.loadSynced(
        bandId: bandId,
        songId: songId,
      );
      if (!ref.mounted || presets.isEmpty) return;
      final byId = <String, Tuning>{
        for (final tuning in state.customTunings) tuning.id: tuning,
      };
      final scopes = Map<String, TunerPresetScope>.from(
        state.customTuningScopes,
      );
      for (final preset in presets) {
        _customPresetsById[preset.id] = preset;
        byId[preset.id] = Tuning(
          id: preset.id,
          name: preset.name,
          notes: preset.tuningNotes.map((note) => note.displayName).toList(),
        );
        scopes[preset.id] = preset.scope;
      }
      state = state.copyWith(
        customTunings: byId.values.toList(),
        customTuningScopes: scopes,
      );
      final pendingPresetId = _pendingPresetId;
      if (pendingPresetId != null) selectPresetById(pendingPresetId);
    } catch (error) {
      debugPrint('Unable to load synced tuner presets: $error');
    }
  }

  void setDetectionMode(DetectionMode mode) {
    state = state.copyWith(
      detectionMode: mode,
      manualTargetStringIndex: mode == DetectionMode.auto
          ? null
          : state.manualTargetStringIndex,
    );
  }

  void toggleDetectionMode() {
    setDetectionMode(
      state.detectionMode == DetectionMode.auto
          ? DetectionMode.manual
          : DetectionMode.auto,
    );
  }

  void setManualTargetStringIndex(int index) {
    final tuning = state.selectedTuning;
    if (tuning == null || index < 0 || index >= tuning.notes.length) return;
    state = state.copyWith(
      manualTargetStringIndex: index,
      note: tuning.notes[index],
      cents: 0,
    );
    _resetStability();
  }

  void setTargetNoteByIndex(int chromaticIndex) {
    const notes = <String>[
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
    setToneNote(notes[chromaticIndex % 12], 4);
  }

  double parseNoteNameToFrequency(String noteName) {
    return TunerNoteMath.frequencyForNote(noteName, state.referenceA4);
  }

  Future<void> addCustomTuning(
    Tuning tuning, {
    TunerPresetScope scope = TunerPresetScope.local,
    String? bandId,
    String? songId,
  }) async {
    final now = DateTime.now();
    final preset = TunerPreset(
      id: tuning.id,
      name: tuning.name,
      instrumentType: InstrumentType.custom,
      tuningNotes: [
        for (var index = 0; index < tuning.notes.length; index++)
          _tuningNote(tuning.notes[index], index),
      ],
      referenceHz: state.referenceA4,
      centsTolerance: state.centsTolerance,
      scope: scope,
      bandId: bandId,
      songId: songId,
      createdAt: now,
      updatedAt: now,
    );
    await _presetRepository.save(preset);
    _customPresetsById[preset.id] = preset;
    final existing = state.customTunings.where(
      (value) => value.id != tuning.id,
    );
    state = state.copyWith(
      customTunings: [...existing, tuning],
      customTuningScopes: {...state.customTuningScopes, tuning.id: scope},
    );
    unawaited(
      AnalyticsService.logTunerEvent('tuner_preset_saved', {
        'scope': preset.scope.name,
      }),
    );
  }

  TuningNote _tuningNote(String displayName, int index) {
    final match = RegExp(r'^([A-Ga-g][#b]?)(-?\d+)$').firstMatch(displayName);
    if (match == null) {
      throw FormatException('Invalid tuning note: $displayName');
    }
    return TuningNote(
      note: match.group(1)!,
      octave: int.parse(match.group(2)!),
      targetFrequencyHz: parseNoteNameToFrequency(displayName),
      stringNumber: index + 1,
    );
  }

  Future<void> removeCustomTuning(String tuningId) async {
    final preset = _customPresetsById[tuningId];
    if (preset != null) await _presetRepository.delete(preset);
    _customPresetsById.remove(tuningId);
    state = state.copyWith(
      customTunings: state.customTunings
          .where((value) => value.id != tuningId)
          .toList(),
      customTuningScopes: Map<String, TunerPresetScope>.from(
        state.customTuningScopes,
      )..remove(tuningId),
    );
  }

  void toggleStageModeEnabled() {
    state = state.copyWith(
      stageModeEnabled: !state.stageModeEnabled,
      stageModeActive: false,
    );
  }

  void setStageModeActive({required bool active}) {
    state = state.copyWith(stageModeActive: active);
  }

  void exitStageMode() => state = state.copyWith(stageModeActive: false);

  void cycleMusicMode() {
    state = state.copyWith(
      musicModeIndex: (state.musicModeIndex + 1) % allMusicModes.length,
    );
    if (state.hapticEnabled) HapticFeedback.mediumImpact();
  }

  void setMusicMode(int index) {
    if (index >= 0 && index < allMusicModes.length) {
      state = state.copyWith(musicModeIndex: index);
    }
  }

  MusicMode get currentMusicMode => allMusicModes[state.musicModeIndex];
  bool isNoteInScale(int noteIndex) => currentMusicMode.containsNote(noteIndex);
}

final tunerProvider = NotifierProvider<TunerNotifier, TunerState>(
  TunerNotifier.new,
);

final tunerModeProvider = Provider<TunerMode>(
  (ref) => ref.watch(tunerProvider).mode,
);
final tunerFrequencyProvider = Provider<double>(
  (ref) => ref.watch(tunerProvider).frequency,
);
final tunerNoteProvider = Provider<String>(
  (ref) => ref.watch(tunerProvider).note,
);
final tunerCentsProvider = Provider<int>(
  (ref) => ref.watch(tunerProvider).cents,
);
final tunerIsPlayingProvider = Provider<bool>(
  (ref) => ref.watch(tunerProvider).isPlaying,
);
final tunerIsListeningProvider = Provider<bool>(
  (ref) => ref.watch(tunerProvider).isListening,
);
final selectedInstrumentProvider = Provider<Instrument?>(
  (ref) => ref.watch(tunerProvider).selectedInstrument,
);
final selectedTuningProvider = Provider<Tuning?>(
  (ref) => ref.watch(tunerProvider).selectedTuning,
);
final detectionModeProvider = Provider<DetectionMode>(
  (ref) => ref.watch(tunerProvider).detectionMode,
);
final manualTargetStringIndexProvider = Provider<int?>(
  (ref) => ref.watch(tunerProvider).manualTargetStringIndex,
);
final customTuningsProvider = Provider<List<Tuning>>(
  (ref) => ref.watch(tunerProvider).customTunings,
);
final stageModeActiveProvider = Provider<bool>(
  (ref) => ref.watch(tunerProvider).stageModeActive,
);
final stageModeEnabledProvider = Provider<bool>(
  (ref) => ref.watch(tunerProvider).stageModeEnabled,
);
