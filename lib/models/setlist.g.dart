// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setlist.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Setlist _$SetlistFromJson(Map<String, dynamic> json) => Setlist(
  id: json['id'] as String? ?? '',
  bandId: json['bandId'] as String? ?? '',
  name: json['name'] as String? ?? '',
  description: json['description'] as String?,
  eventDate: json['eventDate'] as String?,
  eventLocation: json['eventLocation'] as String?,
  songIds:
      (json['songIds'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      [],
  totalDuration: (json['totalDuration'] as num?)?.toInt(),
  createdAt: _parseDateTime(json['createdAt']),
  updatedAt: _parseDateTime(json['updatedAt']),
);

Map<String, dynamic> _$SetlistToJson(Setlist instance) => <String, dynamic>{
  'id': instance.id,
  'bandId': instance.bandId,
  'name': instance.name,
  'description': instance.description,
  'eventDate': instance.eventDate,
  'eventLocation': instance.eventLocation,
  'songIds': instance.songIds,
  'totalDuration': instance.totalDuration,
  'createdAt': _dateTimeToJson(instance.createdAt),
  'updatedAt': _dateTimeToJson(instance.updatedAt),
};
