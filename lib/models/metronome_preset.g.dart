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
      'createdAt': _dateTimeToJson(instance.createdAt),
    };
