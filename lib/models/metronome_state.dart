import 'package:json_annotation/json_annotation.dart';

import 'beat_mode.dart';
import 'metronome_runtime_state.dart';
import 'setlist.dart';
import 'song.dart';
import 'tempo_ramp.dart';
import 'time_signature.dart';

part 'metronome_state.g.dart';

const Object _metronomeStateNoChange = Object();

/// Immutable state class for MetronomeNotifier
@JsonSerializable()
class MetronomeState {
  const MetronomeState({
    required this.isPlaying,
    required this.bpm,
    required this.currentBeat,
    required this.timeSignature,
    required this.waveType,
    required this.volume,
    required this.accentEnabled,
    required this.accentFrequency,
    required this.beatFrequency,
    required this.accentPattern,
    this.accentBeatFrequency = 2000,
    this.hapticsEnabled = true,
    this.accentBeats = 4,
    this.regularBeats = 1,
    this.beatModes = const [], // Empty = all normal (2D: beats × subdivisions)
    this.loadedSong,
    this.loadedSetlist,
    this.loadedSetlistSongs = const [],
    this.sourceBandId,
    this.currentSetlistIndex = 0,
    this.countInBars = 0,
    this.bpmSource = BpmSource.manual,
    this.playbackPhase = MetronomePlaybackPhase.stopped,
    this.activePresetId,
    this.activePresetName,
    this.visualFlashEnabled = true,
    this.activeTempoRamp,
    this.completedBars = 0,
  });

  factory MetronomeState.initial() {
    return const MetronomeState(
      isPlaying: false,
      bpm: 120,
      currentBeat: 0,
      timeSignature: TimeSignature.commonTime,
      waveType: 'sine',
      volume: 0.5,
      accentEnabled: true,
      accentFrequency: 1600,
      beatFrequency: 800,
      accentPattern: [true, false, false, false],
    );
  }

  factory MetronomeState.fromJson(Map<String, dynamic> json) =>
      _$MetronomeStateFromJson(json);

  @JsonKey(defaultValue: false)
  final bool isPlaying;
  @JsonKey(defaultValue: 120)
  final int bpm;
  @JsonKey(defaultValue: 0)
  final int currentBeat;
  final TimeSignature timeSignature;
  @JsonKey(defaultValue: 'sine')
  final String waveType;
  @JsonKey(defaultValue: 0.5)
  final double volume;
  @JsonKey(defaultValue: true)
  final bool accentEnabled;

  /// Pitch of the main beat (first subdivision of each beat / "downbeat").
  /// Surfaced in the UI as the "Primary pitch" control.
  @JsonKey(defaultValue: 1600)
  final double accentFrequency;

  /// Pitch of every non-main subdivision. Surfaced as the "Subdivision pitch"
  /// control.
  @JsonKey(defaultValue: 800)
  final double beatFrequency;

  /// Pitch of cells explicitly marked [BeatMode.accent] in the beat map
  /// (rendered cyan). Surfaced as the "Accent pitch" control.
  @JsonKey(defaultValue: 2000)
  final double accentBeatFrequency;
  @JsonKey(defaultValue: true)
  final bool hapticsEnabled;
  @JsonKey(defaultValue: [])
  final List<bool> accentPattern;

  // NEW: UI state for Mono Pulse design (NEW LOGIC)
  @JsonKey(defaultValue: 4)
  final int accentBeats; // BEATS count (top row, first number of time signature)
  @JsonKey(defaultValue: 1)
  final int regularBeats; // SUBDIVISIONS per beat (bottom row)
  @JsonKey(defaultValue: [])
  final List<List<BeatMode>> beatModes; // 2D: beats × subdivisions (independent modes)
  final Song? loadedSong;
  final Setlist? loadedSetlist;
  @JsonKey(defaultValue: [])
  final List<Song> loadedSetlistSongs;
  final String? sourceBandId;
  @JsonKey(defaultValue: 0)
  final int currentSetlistIndex;

  // Count-in feature
  @JsonKey(defaultValue: 0)
  final int countInBars;
  @JsonKey(defaultValue: BpmSource.manual)
  final BpmSource bpmSource;
  @JsonKey(defaultValue: MetronomePlaybackPhase.stopped)
  final MetronomePlaybackPhase playbackPhase;
  final String? activePresetId;
  final String? activePresetName;
  @JsonKey(defaultValue: true)
  final bool visualFlashEnabled;
  final TempoRamp? activeTempoRamp;
  @JsonKey(defaultValue: 0)
  final int completedBars;

  MetronomeState copyWith({
    bool? isPlaying,
    int? bpm,
    int? currentBeat,
    TimeSignature? timeSignature,
    String? waveType,
    double? volume,
    bool? accentEnabled,
    double? accentFrequency,
    double? beatFrequency,
    double? accentBeatFrequency,
    bool? hapticsEnabled,
    List<bool>? accentPattern,
    int? accentBeats,
    int? regularBeats,
    List<List<BeatMode>>? beatModes,
    Object? loadedSong = _metronomeStateNoChange,
    Object? loadedSetlist = _metronomeStateNoChange,
    List<Song>? loadedSetlistSongs,
    Object? sourceBandId = _metronomeStateNoChange,
    int? currentSetlistIndex,
    int? countInBars,
    BpmSource? bpmSource,
    MetronomePlaybackPhase? playbackPhase,
    Object? activePresetId = _metronomeStateNoChange,
    Object? activePresetName = _metronomeStateNoChange,
    bool? visualFlashEnabled,
    Object? activeTempoRamp = _metronomeStateNoChange,
    int? completedBars,
  }) {
    return MetronomeState(
      isPlaying: isPlaying ?? this.isPlaying,
      bpm: bpm ?? this.bpm,
      currentBeat: currentBeat ?? this.currentBeat,
      timeSignature: timeSignature ?? this.timeSignature,
      waveType: waveType ?? this.waveType,
      volume: volume ?? this.volume,
      accentEnabled: accentEnabled ?? this.accentEnabled,
      accentFrequency: accentFrequency ?? this.accentFrequency,
      beatFrequency: beatFrequency ?? this.beatFrequency,
      accentBeatFrequency: accentBeatFrequency ?? this.accentBeatFrequency,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      accentPattern: accentPattern ?? this.accentPattern,
      accentBeats: accentBeats ?? this.accentBeats,
      regularBeats: regularBeats ?? this.regularBeats,
      beatModes: beatModes ?? this.beatModes,
      loadedSong: identical(loadedSong, _metronomeStateNoChange)
          ? this.loadedSong
          : loadedSong as Song?,
      loadedSetlist: identical(loadedSetlist, _metronomeStateNoChange)
          ? this.loadedSetlist
          : loadedSetlist as Setlist?,
      loadedSetlistSongs: loadedSetlistSongs ?? this.loadedSetlistSongs,
      sourceBandId: identical(sourceBandId, _metronomeStateNoChange)
          ? this.sourceBandId
          : sourceBandId as String?,
      currentSetlistIndex: currentSetlistIndex ?? this.currentSetlistIndex,
      countInBars: countInBars ?? this.countInBars,
      bpmSource: bpmSource ?? this.bpmSource,
      playbackPhase: playbackPhase ?? this.playbackPhase,
      activePresetId: identical(activePresetId, _metronomeStateNoChange)
          ? this.activePresetId
          : activePresetId as String?,
      activePresetName: identical(activePresetName, _metronomeStateNoChange)
          ? this.activePresetName
          : activePresetName as String?,
      visualFlashEnabled: visualFlashEnabled ?? this.visualFlashEnabled,
      activeTempoRamp: identical(activeTempoRamp, _metronomeStateNoChange)
          ? this.activeTempoRamp
          : activeTempoRamp as TempoRamp?,
      completedBars: completedBars ?? this.completedBars,
    );
  }

  Map<String, dynamic> toJson() => _$MetronomeStateToJson(this);

  // Backward compatibility getters
  /// Returns beats per measure (alias for accentBeats)
  int get beatsPerMeasure => accentBeats;

  Song? get currentSetlistSong {
    if (currentSetlistIndex < 0 ||
        currentSetlistIndex >= loadedSetlistSongs.length) {
      return null;
    }
    return loadedSetlistSongs[currentSetlistIndex];
  }

  Song? get activeSong => currentSetlistSong ?? loadedSong;

  bool get canGoToPreviousSetlistSong =>
      loadedSetlist != null && currentSetlistIndex > 0;

  bool get canGoToNextSetlistSong =>
      loadedSetlist != null &&
      currentSetlistIndex < loadedSetlistSongs.length - 1;

  /// Check if a beat index should be accented based on accentPattern
  bool isAccentBeat(int beatIndex) {
    if (beatIndex < 0 || beatIndex >= accentPattern.length) return false;
    return accentPattern[beatIndex];
  }
}
