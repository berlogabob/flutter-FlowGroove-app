import 'package:json_annotation/json_annotation.dart';
import 'time_signature.dart';

part 'metronome_state.g.dart';

/// Immutable state class for MetronomeNotifier
///
/// Contains all metronome state fields in an immutable structure.
/// When any field changes, a new MetronomeState instance is created.
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
  });

  /// Creates initial metronome state
  factory MetronomeState.initial() {
    return MetronomeState(
      isPlaying: false,
      bpm: 120,
      currentBeat: 0,
      timeSignature: TimeSignature.commonTime,
      waveType: 'sine',
      volume: 0.5,
      accentEnabled: true,
      accentFrequency: 1600, // Hz (Reaper-style)
      beatFrequency: 800, // Hz (Reaper-style)
      accentPattern: [true, false, false, false], // ABBB for 4/4
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
      accentPattern: accentPattern ?? List.unmodifiable(this.accentPattern),
    );
  }

  /// Get beats per measure from time signature
  int get beatsPerMeasure => timeSignature.numerator;

  /// Check if a beat index should be accented based on current pattern
  bool isAccentBeat(int beatIndex) {
    if (beatIndex < 0 || beatIndex >= accentPattern.length) return false;
    return accentPattern[beatIndex];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MetronomeState &&
          runtimeType == other.runtimeType &&
          isPlaying == other.isPlaying &&
          bpm == other.bpm &&
          currentBeat == other.currentBeat &&
          timeSignature == other.timeSignature &&
          waveType == other.waveType &&
          volume == other.volume &&
          accentEnabled == other.accentEnabled &&
          accentFrequency == other.accentFrequency &&
          beatFrequency == other.beatFrequency &&
          _listEquals(accentPattern, other.accentPattern);

  @override
  int get hashCode => Object.hash(
    isPlaying,
    bpm,
    currentBeat,
    timeSignature,
    waveType,
    volume,
    accentEnabled,
    accentFrequency,
    beatFrequency,
    accentPattern,
  );

  bool _listEquals(List<bool> a, List<bool> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() {
    return 'MetronomeState(isPlaying: $isPlaying, bpm: $bpm, currentBeat: $currentBeat, '
        'timeSignature: $timeSignature, waveType: $waveType, volume: $volume, '
        'accentEnabled: $accentEnabled, accentFrequency: $accentFrequency, '
        'beatFrequency: $beatFrequency, accentPattern: $accentPattern)';
  }

  Map<String, dynamic> toJson() => _$MetronomeStateToJson(this);

  factory MetronomeState.fromJson(Map<String, dynamic> json) =>
      _$MetronomeStateFromJson(json);
}
