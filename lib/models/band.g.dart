// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'band.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BandMember _$BandMemberFromJson(Map<String, dynamic> json) => BandMember(
  uid: json['uid'] as String? ?? '',
  role: json['role'] as String? ?? 'viewer',
  displayName: json['displayName'] as String?,
  email: json['email'] as String?,
  musicRoles:
      (json['musicRoles'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
);

Map<String, dynamic> _$BandMemberToJson(BandMember instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'role': instance.role,
      'displayName': instance.displayName,
      'email': instance.email,
      'musicRoles': instance.musicRoles,
    };

Band _$BandFromJson(Map<String, dynamic> json) => Band(
  id: json['id'] as String? ?? '',
  name: json['name'] as String? ?? '',
  description: json['description'] as String?,
  createdBy: json['createdBy'] as String? ?? '',
  members: json['members'] == null ? [] : _membersFromJson(json['members']),
  memberUids:
      (json['memberUids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
  adminUids:
      (json['adminUids'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      [],
  editorUids:
      (json['editorUids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
  inviteCode: json['inviteCode'] as String?,
  createdAt: _parseDateTime(json['createdAt']),
);

Map<String, dynamic> _$BandToJson(Band instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'createdBy': instance.createdBy,
  'members': _membersToJson(instance.members),
  'memberUids': instance.memberUids,
  'adminUids': instance.adminUids,
  'editorUids': instance.editorUids,
  'tags': instance.tags,
  'inviteCode': instance.inviteCode,
  'createdAt': _dateTimeToJson(instance.createdAt),
};
