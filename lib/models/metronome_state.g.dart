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
      hapticsEnabled: json['hapticsEnabled'] as bool? ?? true,
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
      loadedSetlistSongs:
          (json['loadedSetlistSongs'] as List<dynamic>?)
              ?.map((e) => Song.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      sourceBandId: json['sourceBandId'] as String?,
      currentSetlistIndex: (json['currentSetlistIndex'] as num?)?.toInt() ?? 0,
      countInBars: (json['countInBars'] as num?)?.toInt() ?? 0,
      bpmSource:
          $enumDecodeNullable(_$BpmSourceEnumMap, json['bpmSource']) ??
          BpmSource.manual,
      playbackPhase:
          $enumDecodeNullable(
            _$MetronomePlaybackPhaseEnumMap,
            json['playbackPhase'],
          ) ??
          MetronomePlaybackPhase.stopped,
      activePresetId: json['activePresetId'] as String?,
      activePresetName: json['activePresetName'] as String?,
      visualFlashEnabled: json['visualFlashEnabled'] as bool? ?? true,
      activeTempoRamp: json['activeTempoRamp'] == null
          ? null
          : TempoRamp.fromJson(json['activeTempoRamp'] as Map<String, dynamic>),
      completedBars: (json['completedBars'] as num?)?.toInt() ?? 0,
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
      'hapticsEnabled': instance.hapticsEnabled,
      'accentPattern': instance.accentPattern,
      'accentBeats': instance.accentBeats,
      'regularBeats': instance.regularBeats,
      'beatModes': instance.beatModes
          .map((e) => e.map((e) => _$BeatModeEnumMap[e]!).toList())
          .toList(),
      'loadedSong': instance.loadedSong,
      'loadedSetlist': instance.loadedSetlist,
      'loadedSetlistSongs': instance.loadedSetlistSongs,
      'sourceBandId': instance.sourceBandId,
      'currentSetlistIndex': instance.currentSetlistIndex,
      'countInBars': instance.countInBars,
      'bpmSource': _$BpmSourceEnumMap[instance.bpmSource]!,
      'playbackPhase': _$MetronomePlaybackPhaseEnumMap[instance.playbackPhase]!,
      'activePresetId': instance.activePresetId,
      'activePresetName': instance.activePresetName,
      'visualFlashEnabled': instance.visualFlashEnabled,
      'activeTempoRamp': instance.activeTempoRamp,
      'completedBars': instance.completedBars,
    };

const _$BeatModeEnumMap = {
  BeatMode.normal: 'normal',
  BeatMode.accent: 'accent',
  BeatMode.silent: 'silent',
};

const _$BpmSourceEnumMap = {
  BpmSource.manual: 'manual',
  BpmSource.song: 'song',
  BpmSource.setlist: 'setlist',
  BpmSource.preset: 'preset',
  BpmSource.tapTempo: 'tapTempo',
  BpmSource.tempoRamp: 'tempoRamp',
};

const _$MetronomePlaybackPhaseEnumMap = {
  MetronomePlaybackPhase.stopped: 'stopped',
  MetronomePlaybackPhase.countIn: 'countIn',
  MetronomePlaybackPhase.playing: 'playing',
  MetronomePlaybackPhase.pausedByLifecycle: 'pausedByLifecycle',
  MetronomePlaybackPhase.error: 'error',
};
