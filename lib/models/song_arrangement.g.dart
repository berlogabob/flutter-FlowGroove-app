// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'song_arrangement.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SongArrangement _$SongArrangementFromJson(Map<String, dynamic> json) =>
    SongArrangement(
      id: json['id'] as String,
      canonicalSongId: json['canonicalSongId'] as String,
      ownerType: json['ownerType'] as String,
      ownerId: json['ownerId'] as String,
      bandId: json['bandId'] as String?,
      arrangementType:
          $enumDecodeNullable(
            _$ArrangementTypeEnumMap,
            json['arrangementType'],
          ) ??
          ArrangementType.original,
      versionName: json['versionName'] as String?,
      key: json['key'] as String?,
      tempoBpm: (json['tempoBpm'] as num?)?.toInt(),
      capoFret: (json['capoFret'] as num?)?.toInt(),
      structure: json['structure'] as Map<String, dynamic>?,
      notes: json['notes'] as String?,
      isPublic: json['isPublic'] as bool? ?? false,
      forkedFrom: json['forkedFrom'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$SongArrangementToJson(SongArrangement instance) =>
    <String, dynamic>{
      'id': instance.id,
      'canonicalSongId': instance.canonicalSongId,
      'ownerType': instance.ownerType,
      'ownerId': instance.ownerId,
      'bandId': instance.bandId,
      'arrangementType': _$ArrangementTypeEnumMap[instance.arrangementType]!,
      'versionName': instance.versionName,
      'key': instance.key,
      'tempoBpm': instance.tempoBpm,
      'capoFret': instance.capoFret,
      'structure': instance.structure,
      'notes': instance.notes,
      'isPublic': instance.isPublic,
      'forkedFrom': instance.forkedFrom,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

const _$ArrangementTypeEnumMap = {
  ArrangementType.original: 'original',
  ArrangementType.live: 'live',
  ArrangementType.acoustic: 'acoustic',
  ArrangementType.remix: 'remix',
  ArrangementType.cover: 'cover',
  ArrangementType.instrumental: 'instrumental',
  ArrangementType.custom: 'custom',
};
