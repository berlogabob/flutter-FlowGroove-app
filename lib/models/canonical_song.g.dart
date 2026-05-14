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
  schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
  canonicalRevision: (json['canonicalRevision'] as num?)?.toInt() ?? 1,
  source: json['source'] as String? ?? 'manual',
  status: json['status'] as String? ?? 'active',
  createdBy: json['createdBy'] as String?,
  baseKey: json['baseKey'] as String?,
  baseBpm: (json['baseBpm'] as num?)?.toInt(),
  baseSections: json['baseSections'] == null
      ? []
      : _sectionsFromJson(json['baseSections']),
  baseAccentBeats: (json['baseAccentBeats'] as num?)?.toInt() ?? 4,
  baseRegularBeats: (json['baseRegularBeats'] as num?)?.toInt() ?? 1,
  baseBeatModes: json['baseBeatModes'] == null
      ? []
      : _beatModesFromJson(json['baseBeatModes']),
  baseLinks: json['baseLinks'] == null ? [] : _linksFromJson(json['baseLinks']),
  createdAt: _parseDateTime(json['createdAt']),
  updatedAt: _parseDateTime(json['updatedAt']),
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
      'schemaVersion': instance.schemaVersion,
      'canonicalRevision': instance.canonicalRevision,
      'source': instance.source,
      'status': instance.status,
      'createdBy': instance.createdBy,
      'baseKey': instance.baseKey,
      'baseBpm': instance.baseBpm,
      'baseSections': _sectionsToJson(instance.baseSections),
      'baseAccentBeats': instance.baseAccentBeats,
      'baseRegularBeats': instance.baseRegularBeats,
      'baseBeatModes': _beatModesToJson(instance.baseBeatModes),
      'baseLinks': _linksToJson(instance.baseLinks),
      'createdAt': _dateTimeToJson(instance.createdAt),
      'updatedAt': _dateTimeToJson(instance.updatedAt),
    };
