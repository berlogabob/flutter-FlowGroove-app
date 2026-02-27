// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppUser _$AppUserFromJson(Map<String, dynamic> json) => AppUser(
  uid: json['uid'] as String? ?? '',
  displayName: json['displayName'] as String?,
  email: json['email'] as String?,
  photoURL: json['photoURL'] as String?,
  bandIds:
      (json['bandIds'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      [],
  baseTags:
      (json['baseTags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      [],
  createdAt: _parseDateTime(json['createdAt']),
);

Map<String, dynamic> _$AppUserToJson(AppUser instance) => <String, dynamic>{
  'uid': instance.uid,
  'displayName': instance.displayName,
  'email': instance.email,
  'photoURL': instance.photoURL,
  'bandIds': instance.bandIds,
  'baseTags': instance.baseTags,
  'createdAt': _dateTimeToJson(instance.createdAt),
};
