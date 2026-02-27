import 'package:json_annotation/json_annotation.dart';
import 'time_signature.dart';
import 'beat_mode.dart';
import 'song.dart';
import '../models/setlist.dart';

part 'metronome_state.g.dart';

/// Immutable state class for MetronomeNotifier
@JsonSerializable()
class MetronomeState {
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
  @JsonKey(defaultValue: 1600)
  final double accentFrequency;
  @JsonKey(defaultValue: 800)
  final double beatFrequency;
  @JsonKey(defaultValue: [])
  final List<bool> accentPattern;

  // NEW: UI state for Mono Pulse design (NEW LOGIC)
  @JsonKey(defaultValue: 4)
  final int accentBeats; // BEATS count (top row, first number of time signature)
  @JsonKey(defaultValue: 1)
  final int regularBeats; // SUBDIVISIONS per beat (bottom row)
  @JsonKey(defaultValue: [])
  final List<List<BeatMode>> beatModes; // 2D: beats × subdivisions (independent modes)
  @JsonKey(defaultValue: null)
  final Song? loadedSong;
  @JsonKey(defaultValue: null)
  final Setlist? loadedSetlist;
  @JsonKey(defaultValue: 0)
  final int currentSetlistIndex;

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
    this.accentBeats = 4,
    this.regularBeats = 1,
    this.beatModes = const [], // Empty = all normal (2D: beats × subdivisions)
    this.loadedSong,
    this.loadedSetlist,
    this.currentSetlistIndex = 0,
  });

  /// Creates initial metronome state
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
      accentBeats: 4,
      regularBeats: 1,
      beatModes: [], // Empty = all normal
    );
  }

  /// Creates a copy of this state with the given fields replaced
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
    List<bool>? accentPattern,
    int? accentBeats,
    int? regularBeats,
    List<List<BeatMode>>? beatModes,
    Song? loadedSong,
    Setlist? loadedSetlist,
    int? currentSetlistIndex,
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
      accentPattern: accentPattern ?? this.accentPattern,
      accentBeats: accentBeats ?? this.accentBeats,
      regularBeats: regularBeats ?? this.regularBeats,
      beatModes: beatModes ?? this.beatModes,
      loadedSong: loadedSong ?? this.loadedSong,
      loadedSetlist: loadedSetlist ?? this.loadedSetlist,
      currentSetlistIndex: currentSetlistIndex ?? this.currentSetlistIndex,
    );
  }

  /// Convert from JSON
  factory MetronomeState.fromJson(Map<String, dynamic> json) =>
      _$MetronomeStateFromJson(json);

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$MetronomeStateToJson(this);

  // Backward compatibility getters
  /// Returns beats per measure (alias for accentBeats)
  int get beatsPerMeasure => accentBeats;

  /// Check if a beat index should be accented based on accentPattern
  bool isAccentBeat(int beatIndex) {
    if (beatIndex < 0 || beatIndex >= accentPattern.length) return false;
    return accentPattern[beatIndex];
  }
}
