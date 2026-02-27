// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setlist_assignment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SetlistAssignment _$SetlistAssignmentFromJson(Map<String, dynamic> json) =>
    SetlistAssignment(
      oderId: json['oderId'] as String? ?? '',
      roleOverride: json['roleOverride'] as String?,
      keyOverride: json['keyOverride'] as String?,
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$SetlistAssignmentToJson(SetlistAssignment instance) =>
    <String, dynamic>{
      'oderId': instance.oderId,
      'roleOverride': instance.roleOverride,
      'keyOverride': instance.keyOverride,
      'notes': instance.notes,
    };
