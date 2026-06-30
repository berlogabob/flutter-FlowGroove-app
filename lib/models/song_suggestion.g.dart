// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'song_suggestion.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SongSuggestion _$SongSuggestionFromJson(Map<String, dynamic> json) =>
    SongSuggestion(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      source: $enumDecode(_$SuggestionSourceEnumMap, json['source']),
      type: $enumDecode(_$SuggestionTypeEnumMap, json['type']),
      matchScore: (json['matchScore'] as num?)?.toDouble() ?? 1.0,
      bandId: json['bandId'] as String?,
      bandName: json['bandName'] as String?,
      canonicalSongId: json['canonicalSongId'] as String?,
      variantInfo: json['variantInfo'] as String?,
      bpm: (json['bpm'] as num?)?.toInt(),
      key: json['key'] as String?,
      isForkable: json['isForkable'] as bool? ?? false,
      album: json['album'] as String?,
      releaseYear: (json['releaseYear'] as num?)?.toInt(),
      durationMs: (json['durationMs'] as num?)?.toInt(),
      musicBrainzId: json['musicBrainzId'] as String?,
      spotifyId: json['spotifyId'] as String?,
      matchReasons:
          (json['matchReasons'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );

Map<String, dynamic> _$SongSuggestionToJson(SongSuggestion instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'artist': instance.artist,
      'source': _$SuggestionSourceEnumMap[instance.source]!,
      'type': _$SuggestionTypeEnumMap[instance.type]!,
      'matchScore': instance.matchScore,
      'bandId': instance.bandId,
      'bandName': instance.bandName,
      'canonicalSongId': instance.canonicalSongId,
      'variantInfo': instance.variantInfo,
      'bpm': instance.bpm,
      'key': instance.key,
      'isForkable': instance.isForkable,
      'album': instance.album,
      'releaseYear': instance.releaseYear,
      'durationMs': instance.durationMs,
      'musicBrainzId': instance.musicBrainzId,
      'spotifyId': instance.spotifyId,
      'matchReasons': instance.matchReasons,
    };

const _$SuggestionSourceEnumMap = {
  SuggestionSource.personal: 'personal',
  SuggestionSource.group: 'group',
  SuggestionSource.musicbrainz: 'musicbrainz',
  SuggestionSource.spotify: 'spotify',
  SuggestionSource.canonical: 'canonical',
};

const _$SuggestionTypeEnumMap = {
  SuggestionType.exact: 'exact',
  SuggestionType.similar: 'similar',
  SuggestionType.variant: 'variant',
};
