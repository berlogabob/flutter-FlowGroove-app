// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'song.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Song _$SongFromJson(Map<String, dynamic> json) => Song(
  id: json['id'] as String? ?? '',
  title: json['title'] as String? ?? '',
  artist: json['artist'] as String? ?? '',
  originalKey: json['originalKey'] as String?,
  originalBPM: (json['originalBPM'] as num?)?.toInt(),
  ourKey: json['ourKey'] as String?,
  ourBPM: (json['ourBPM'] as num?)?.toInt(),
  links: json['links'] == null ? [] : _linksFromJson(json['links']),
  notes: json['notes'] as String?,
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
  bandId: json['bandId'] as String?,
  spotifyUrl: json['spotifyUrl'] as String?,
  createdAt: _parseDateTime(json['createdAt']),
  updatedAt: _parseDateTime(json['updatedAt']),
  originalOwnerId: json['originalOwnerId'] as String?,
  originalSongId: json['originalSongId'] as String?,
  contributedBy: json['contributedBy'] as String?,
  isCopy: json['isCopy'] as bool? ?? false,
  contributedAt: _parseNullableDateTime(json['contributedAt']),
  accentBeats: (json['accentBeats'] as num?)?.toInt() ?? 4,
  regularBeats: (json['regularBeats'] as num?)?.toInt() ?? 1,
  beatModes: json['beatModes'] == null
      ? []
      : _beatModesFromJson(json['beatModes']),
  sections: json['sections'] == null ? [] : _sectionsFromJson(json['sections']),
);

Map<String, dynamic> _$SongToJson(Song instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'artist': instance.artist,
  'originalKey': instance.originalKey,
  'originalBPM': instance.originalBPM,
  'ourKey': instance.ourKey,
  'ourBPM': instance.ourBPM,
  'links': _linksToJson(instance.links),
  'notes': instance.notes,
  'tags': instance.tags,
  'bandId': instance.bandId,
  'spotifyUrl': instance.spotifyUrl,
  'createdAt': _dateTimeToJson(instance.createdAt),
  'updatedAt': _dateTimeToJson(instance.updatedAt),
  'originalOwnerId': instance.originalOwnerId,
  'originalSongId': instance.originalSongId,
  'contributedBy': instance.contributedBy,
  'isCopy': instance.isCopy,
  'contributedAt': _dateTimeToJson(instance.contributedAt),
  'accentBeats': instance.accentBeats,
  'regularBeats': instance.regularBeats,
  'beatModes': _beatModesToJson(instance.beatModes),
  'sections': _sectionsToJson(instance.sections),
};
