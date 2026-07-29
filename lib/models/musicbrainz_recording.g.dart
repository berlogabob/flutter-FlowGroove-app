// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'musicbrainz_recording.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MusicBrainzArtistCredit _$MusicBrainzArtistCreditFromJson(
  Map<String, dynamic> json,
) => MusicBrainzArtistCredit(
  artist: MusicBrainzArtist.fromJson(json['artist'] as Map<String, dynamic>),
  name: json['name'] as String?,
  joinPhrase: json['joinPhrase'] as String?,
);

Map<String, dynamic> _$MusicBrainzArtistCreditToJson(
  MusicBrainzArtistCredit instance,
) => <String, dynamic>{
  'artist': instance.artist,
  'name': instance.name,
  'joinPhrase': instance.joinPhrase,
};

MusicBrainzArtist _$MusicBrainzArtistFromJson(Map<String, dynamic> json) =>
    MusicBrainzArtist(
      id: json['id'] as String,
      name: json['name'] as String,
      disambiguation: json['disambiguation'] as String?,
      sortName: json['sortName'] as String?,
    );

Map<String, dynamic> _$MusicBrainzArtistToJson(MusicBrainzArtist instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'disambiguation': instance.disambiguation,
      'sortName': instance.sortName,
    };

MusicBrainzRelease _$MusicBrainzReleaseFromJson(Map<String, dynamic> json) =>
    MusicBrainzRelease(
      id: json['id'] as String,
      title: json['title'] as String,
      date: json['date'] as String?,
      country: json['country'] as String?,
    );

Map<String, dynamic> _$MusicBrainzReleaseToJson(MusicBrainzRelease instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'date': instance.date,
      'country': instance.country,
    };

MusicBrainzRecording _$MusicBrainzRecordingFromJson(
  Map<String, dynamic> json,
) => MusicBrainzRecording(
  id: json['id'] as String,
  title: json['title'] as String,
  artistCredit:
      (json['artist-credit'] as List<dynamic>?)
          ?.map(
            (e) => MusicBrainzArtistCredit.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      [],
  disambiguation: json['disambiguation'] as String?,
  lengthMs: (json['length'] as num?)?.toInt(),
  isrcs:
      (json['isrcs'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
  releases:
      (json['releases'] as List<dynamic>?)
          ?.map((e) => MusicBrainzRelease.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  aliases:
      (json['aliases'] as List<dynamic>?)
          ?.map((e) => MusicBrainzAlias.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Map<String, dynamic> _$MusicBrainzRecordingToJson(
  MusicBrainzRecording instance,
) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'artist-credit': instance.artistCredit,
  'disambiguation': instance.disambiguation,
  'length': instance.lengthMs,
  'isrcs': instance.isrcs,
  'releases': instance.releases,
  'aliases': instance.aliases,
};

MusicBrainzAlias _$MusicBrainzAliasFromJson(Map<String, dynamic> json) =>
    MusicBrainzAlias(
      name: json['name'] as String,
      locale: json['locale'] as String?,
      primary: json['primary'] as bool?,
    );

Map<String, dynamic> _$MusicBrainzAliasToJson(MusicBrainzAlias instance) =>
    <String, dynamic>{
      'name': instance.name,
      'locale': instance.locale,
      'primary': instance.primary,
    };
