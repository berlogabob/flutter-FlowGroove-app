// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'metronome_preset.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MetronomePreset _$MetronomePresetFromJson(Map<String, dynamic> json) =>
    MetronomePreset(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      bpm: (json['bpm'] as num).toInt(),
      timeSignature: TimeSignature.fromJson(
        json['timeSignature'] as Map<String, dynamic>,
      ),
      waveType: json['waveType'] as String? ?? 'sine',
      accentEnabled: json['accentEnabled'] as bool? ?? true,
      subdivisions: (json['subdivisions'] as num?)?.toInt() ?? 1,
      beatModes:
          (json['beatModes'] as List<dynamic>?)
              ?.map(
                (e) => (e as List<dynamic>)
                    .map((e) => $enumDecode(_$BeatModeEnumMap, e))
                    .toList(),
              )
              .toList() ??
          [],
      volume: (json['volume'] as num?)?.toDouble() ?? 0.5,
      countInBars: (json['countInBars'] as num?)?.toInt() ?? 0,
      visualFlashEnabled: json['visualFlashEnabled'] as bool? ?? true,
      hapticsEnabled: json['hapticsEnabled'] as bool? ?? true,
      soundProfileId: json['soundProfileId'] as String? ?? 'digital',
      createdAt: _parseDateTime(json['createdAt']),
    );

Map<String, dynamic> _$MetronomePresetToJson(MetronomePreset instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'bpm': instance.bpm,
      'timeSignature': instance.timeSignature,
      'waveType': instance.waveType,
      'accentEnabled': instance.accentEnabled,
      'subdivisions': instance.subdivisions,
      'beatModes': instance.beatModes
          .map((e) => e.map((e) => _$BeatModeEnumMap[e]!).toList())
          .toList(),
      'volume': instance.volume,
      'countInBars': instance.countInBars,
      'visualFlashEnabled': instance.visualFlashEnabled,
      'hapticsEnabled': instance.hapticsEnabled,
      'soundProfileId': instance.soundProfileId,
      'createdAt': _dateTimeToJson(instance.createdAt),
    };

const _$BeatModeEnumMap = {
  BeatMode.normal: 'normal',
  BeatMode.accent: 'accent',
  BeatMode.silent: 'silent',
};
