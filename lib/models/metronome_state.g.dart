// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'metronome_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MetronomeState _$MetronomeStateFromJson(Map<String, dynamic> json) =>
    MetronomeState(
      isPlaying: json['isPlaying'] as bool? ?? false,
      bpm: (json['bpm'] as num?)?.toInt() ?? 120,
      currentBeat: (json['currentBeat'] as num?)?.toInt() ?? 0,
      timeSignature: TimeSignature.fromJson(
        json['timeSignature'] as Map<String, dynamic>,
      ),
      waveType: json['waveType'] as String? ?? 'sine',
      volume: (json['volume'] as num?)?.toDouble() ?? 0.5,
      accentEnabled: json['accentEnabled'] as bool? ?? true,
      accentFrequency: (json['accentFrequency'] as num?)?.toDouble() ?? 1600,
      beatFrequency: (json['beatFrequency'] as num?)?.toDouble() ?? 800,
      accentPattern:
          (json['accentPattern'] as List<dynamic>?)
              ?.map((e) => e as bool)
              .toList() ??
          [],
    );

Map<String, dynamic> _$MetronomeStateToJson(MetronomeState instance) =>
    <String, dynamic>{
      'isPlaying': instance.isPlaying,
      'bpm': instance.bpm,
      'currentBeat': instance.currentBeat,
      'timeSignature': instance.timeSignature,
      'waveType': instance.waveType,
      'volume': instance.volume,
      'accentEnabled': instance.accentEnabled,
      'accentFrequency': instance.accentFrequency,
      'beatFrequency': instance.beatFrequency,
      'accentPattern': instance.accentPattern,
    };
