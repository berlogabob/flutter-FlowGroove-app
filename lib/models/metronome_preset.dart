import 'package:json_annotation/json_annotation.dart';

import 'beat_mode.dart';
import 'time_signature.dart';

part 'metronome_preset.g.dart';

/// Preset for metronome settings
@JsonSerializable()
class MetronomePreset {
  const MetronomePreset({
    required this.id,
    required this.name,
    required this.bpm,
    required this.timeSignature,
    required this.waveType,
    required this.accentEnabled,
    required this.createdAt,
    this.subdivisions = 1,
    this.beatModes = const [],
    this.volume = 0.5,
    this.countInBars = 0,
    this.visualFlashEnabled = true,
    this.hapticsEnabled = true,
    this.soundProfileId = 'digital',
  });

  factory MetronomePreset.fromJson(Map<String, dynamic> json) =>
      _$MetronomePresetFromJson(json);

  @JsonKey(defaultValue: '')
  final String id;
  @JsonKey(defaultValue: '')
  final String name;
  final int bpm;
  final TimeSignature timeSignature;
  @JsonKey(defaultValue: 'sine')
  final String waveType;
  @JsonKey(defaultValue: true)
  final bool accentEnabled;
  @JsonKey(defaultValue: 1)
  final int subdivisions;
  @JsonKey(defaultValue: [])
  final List<List<BeatMode>> beatModes;
  @JsonKey(defaultValue: 0.5)
  final double volume;
  @JsonKey(defaultValue: 0)
  final int countInBars;
  @JsonKey(defaultValue: true)
  final bool visualFlashEnabled;
  @JsonKey(defaultValue: true)
  final bool hapticsEnabled;
  @JsonKey(defaultValue: 'digital')
  final String soundProfileId;
  @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)
  final DateTime createdAt;

  Map<String, dynamic> toJson() => _$MetronomePresetToJson(this);

  MetronomePreset copyWith({
    String? id,
    String? name,
    int? bpm,
    TimeSignature? timeSignature,
    String? waveType,
    bool? accentEnabled,
    int? subdivisions,
    List<List<BeatMode>>? beatModes,
    double? volume,
    int? countInBars,
    bool? visualFlashEnabled,
    bool? hapticsEnabled,
    String? soundProfileId,
    DateTime? createdAt,
  }) {
    return MetronomePreset(
      id: id ?? this.id,
      name: name ?? this.name,
      bpm: bpm ?? this.bpm,
      timeSignature: timeSignature ?? this.timeSignature,
      waveType: waveType ?? this.waveType,
      accentEnabled: accentEnabled ?? this.accentEnabled,
      subdivisions: subdivisions ?? this.subdivisions,
      beatModes: beatModes ?? this.beatModes,
      volume: volume ?? this.volume,
      countInBars: countInBars ?? this.countInBars,
      visualFlashEnabled: visualFlashEnabled ?? this.visualFlashEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      soundProfileId: soundProfileId ?? this.soundProfileId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get displayName => '$name ($bpm BPM ${timeSignature.displayName})';

  static final List<MetronomePreset> defaults = [
    MetronomePreset(
      id: 'default_1',
      name: 'Slow Practice',
      bpm: 60,
      timeSignature: TimeSignature.commonTime,
      waveType: 'sine',
      accentEnabled: true,
      createdAt: DateTime(2026),
    ),
    MetronomePreset(
      id: 'default_2',
      name: 'Medium Rock',
      bpm: 120,
      timeSignature: TimeSignature.commonTime,
      waveType: 'square',
      accentEnabled: true,
      createdAt: DateTime(2026),
    ),
    MetronomePreset(
      id: 'default_3',
      name: 'Waltz',
      bpm: 90,
      timeSignature: TimeSignature.waltz,
      waveType: 'sine',
      accentEnabled: true,
      createdAt: DateTime(2026),
    ),
  ];
}

DateTime _parseDateTime(Object? value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  return DateTime.parse(value as String);
}

String? _dateTimeToJson(DateTime? value) => value?.toIso8601String();
