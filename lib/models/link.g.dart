// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'link.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Link _$LinkFromJson(Map<String, dynamic> json) => Link(
  type: json['type'] as String? ?? 'other',
  url: json['url'] as String? ?? '',
  title: json['title'] as String?,
);

Map<String, dynamic> _$LinkToJson(Link instance) => <String, dynamic>{
  'type': instance.type,
  'url': instance.url,
  'title': instance.title,
};
