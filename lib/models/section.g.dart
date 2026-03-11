// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'section.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Section _$SectionFromJson(Map<String, dynamic> json) => Section(
  id: (json['id'] as num?)?.toInt() ?? Isar.autoIncrement,
  name: json['name'] as String,
  notes: json['notes'] as String? ?? '',
  duration: (json['duration'] as num?)?.toInt() ?? 1,
  colorValue: (json['colorValue'] as num?)?.toInt(),
);

Map<String, dynamic> _$SectionToJson(Section instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'notes': instance.notes,
  'duration': instance.duration,
  'colorValue': instance.colorValue,
};
