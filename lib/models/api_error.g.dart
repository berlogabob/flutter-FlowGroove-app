// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_error.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApiError _$ApiErrorFromJson(Map<String, dynamic> json) => ApiError(
  type: $enumDecode(_$ErrorTypeEnumMap, json['type']),
  message: json['message'] as String,
  details: json['details'] as String?,
);

Map<String, dynamic> _$ApiErrorToJson(ApiError instance) => <String, dynamic>{
  'type': _$ErrorTypeEnumMap[instance.type]!,
  'message': instance.message,
  'details': instance.details,
};

const _$ErrorTypeEnumMap = {
  ErrorType.network: 'network',
  ErrorType.auth: 'auth',
  ErrorType.validation: 'validation',
  ErrorType.permission: 'permission',
  ErrorType.notFound: 'notFound',
  ErrorType.unknown: 'unknown',
};
