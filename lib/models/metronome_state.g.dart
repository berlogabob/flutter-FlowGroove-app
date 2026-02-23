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
      accentBeats: (json['accentBeats'] as num?)?.toInt() ?? 4,
      regularBeats: (json['regularBeats'] as num?)?.toInt() ?? 1,
      beatModes:
          (json['beatModes'] as List<dynamic>?)
              ?.map(
                (e) => (e as List<dynamic>)
                    .map((e) => $enumDecode(_$BeatModeEnumMap, e))
                    .toList(),
              )
              .toList() ??
          [],
      loadedSong: json['loadedSong'] == null
          ? null
          : Song.fromJson(json['loadedSong'] as Map<String, dynamic>),
      loadedSetlist: json['loadedSetlist'] == null
          ? null
          : Setlist.fromJson(json['loadedSetlist'] as Map<String, dynamic>),
      currentSetlistIndex: (json['currentSetlistIndex'] as num?)?.toInt() ?? 0,
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
      'accentBeats': instance.accentBeats,
      'regularBeats': instance.regularBeats,
      'beatModes': instance.beatModes
          .map((e) => e.map((e) => _$BeatModeEnumMap[e]!).toList())
          .toList(),
      'loadedSong': instance.loadedSong,
      'loadedSetlist': instance.loadedSetlist,
      'currentSetlistIndex': instance.currentSetlistIndex,
    };

const _$BeatModeEnumMap = {
  BeatMode.normal: 'normal',
  BeatMode.accent: 'accent',
  BeatMode.silent: 'silent',
};
