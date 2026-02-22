// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'time_signature.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TimeSignature _$TimeSignatureFromJson(Map<String, dynamic> json) =>
    TimeSignature(
      numerator: (json['numerator'] as num).toInt(),
      denominator: (json['denominator'] as num).toInt(),
    );

Map<String, dynamic> _$TimeSignatureToJson(TimeSignature instance) =>
    <String, dynamic>{
      'numerator': instance.numerator,
      'denominator': instance.denominator,
    };
