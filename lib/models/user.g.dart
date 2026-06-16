// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppUser _$AppUserFromJson(Map<String, dynamic> json) => AppUser(
  uid: json['uid'] as String? ?? '',
  createdAt: _parseDateTime(json['createdAt']),
  displayName: json['displayName'] as String?,
  email: json['email'] as String?,
  photoURL: json['photoURL'] as String?,
  photoSource: json['photoSource'] as String?,
  accessRole: json['accessRole'] as String? ?? 'member',
  musicRoles:
      (json['musicRoles'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
  systemTags:
      (json['systemTags'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
  bandIds:
      (json['bandIds'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      [],
);

Map<String, dynamic> _$AppUserToJson(AppUser instance) => <String, dynamic>{
  'uid': instance.uid,
  'displayName': instance.displayName,
  'email': instance.email,
  'photoURL': instance.photoURL,
  'photoSource': instance.photoSource,
  'accessRole': instance.accessRole,
  'musicRoles': instance.musicRoles,
  'systemTags': instance.systemTags,
  'bandIds': instance.bandIds,
  'createdAt': _dateTimeToJson(instance.createdAt),
};
