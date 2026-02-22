// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'song_form_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SongFormData _$SongFormDataFromJson(Map<String, dynamic> json) => SongFormData(
  title: json['title'] as String? ?? '',
  artist: json['artist'] as String? ?? '',
  originalBpm: json['originalBpm'] as String? ?? '',
  ourBpm: json['ourBpm'] as String? ?? '',
  notes: json['notes'] as String? ?? '',
  links: (json['links'] as List<dynamic>?)
      ?.map((e) => Link.fromJson(e as Map<String, dynamic>))
      .toList(),
  selectedTags: (json['selectedTags'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  originalKeyBase: json['originalKeyBase'] as String? ?? 'C',
  originalKeyModifier: json['originalKeyModifier'] as String? ?? '',
  ourKeyBase: json['ourKeyBase'] as String? ?? 'C',
  ourKeyModifier: json['ourKeyModifier'] as String? ?? '',
  spotifyUrl: json['spotifyUrl'] as String?,
);

Map<String, dynamic> _$SongFormDataToJson(SongFormData instance) =>
    <String, dynamic>{
      'title': instance.title,
      'artist': instance.artist,
      'originalBpm': instance.originalBpm,
      'ourBpm': instance.ourBpm,
      'notes': instance.notes,
      'links': instance.links,
      'selectedTags': instance.selectedTags,
      'originalKeyBase': instance.originalKeyBase,
      'originalKeyModifier': instance.originalKeyModifier,
      'ourKeyBase': instance.ourKeyBase,
      'ourKeyModifier': instance.ourKeyModifier,
      'spotifyUrl': instance.spotifyUrl,
    };
