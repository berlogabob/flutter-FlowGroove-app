// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'canonical_song.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CanonicalSong _$CanonicalSongFromJson(
  Map<String, dynamic> json,
) => CanonicalSong(
  id: json['id'] as String,
  title: json['title'] as String,
  artist: json['artist'] as String,
  artists:
      (json['artists'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      [],
  album: json['album'] as String?,
  releaseYear: (json['releaseYear'] as num?)?.toInt(),
  durationMs: (json['durationMs'] as num?)?.toInt(),
  isrc: json['isrc'] as String?,
  spotifyId: json['spotifyId'] as String?,
  musicBrainzId: json['musicBrainzId'] as String?,
  musicBrainzWorkId: json['musicBrainzWorkId'] as String?,
  iswc: json['iswc'] as String?,
  normalizedTitle: json['normalizedTitle'] as String?,
  normalizedArtist: json['normalizedArtist'] as String?,
  genres:
      (json['genres'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      [],
  disambiguation: json['disambiguation'] as String?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$CanonicalSongToJson(CanonicalSong instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'artist': instance.artist,
      'artists': instance.artists,
      'album': instance.album,
      'releaseYear': instance.releaseYear,
      'durationMs': instance.durationMs,
      'isrc': instance.isrc,
      'spotifyId': instance.spotifyId,
      'musicBrainzId': instance.musicBrainzId,
      'musicBrainzWorkId': instance.musicBrainzWorkId,
      'iswc': instance.iswc,
      'normalizedTitle': instance.normalizedTitle,
      'normalizedArtist': instance.normalizedArtist,
      'genres': instance.genres,
      'disambiguation': instance.disambiguation,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
