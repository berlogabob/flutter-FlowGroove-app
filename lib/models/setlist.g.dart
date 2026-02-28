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
  eventDateTime: _parseTimestamp(json['eventDateTime']),
  eventLocation: json['eventLocation'] as String?,
  songIds:
      (json['songIds'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      [],
  totalDuration: (json['totalDuration'] as num?)?.toInt(),
  assignments: json['assignments'] == null
      ? {}
      : _assignmentsFromJson(json['assignments']),
  createdAt: _parseDateTime(json['createdAt']),
  updatedAt: _parseDateTime(json['updatedAt']),
);

Map<String, dynamic> _$SetlistToJson(Setlist instance) => <String, dynamic>{
  'id': instance.id,
  'bandId': instance.bandId,
  'name': instance.name,
  'description': instance.description,
  'eventDateTime': instance.eventDateTime?.toIso8601String(),
  'eventLocation': instance.eventLocation,
  'songIds': instance.songIds,
  'totalDuration': instance.totalDuration,
  'assignments': _assignmentsToJson(instance.assignments),
  'createdAt': _dateTimeToJson(instance.createdAt),
  'updatedAt': _dateTimeToJson(instance.updatedAt),
};
