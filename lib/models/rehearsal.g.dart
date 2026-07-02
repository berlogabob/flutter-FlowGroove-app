// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rehearsal.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CandidateSlot _$CandidateSlotFromJson(Map<String, dynamic> json) =>
    CandidateSlot(
      id: json['id'] as String? ?? '',
      startTime: _parseDateTime(json['startTime']),
      endTime: _parseDateTime(json['endTime']),
    );

Map<String, dynamic> _$CandidateSlotToJson(CandidateSlot instance) =>
    <String, dynamic>{
      'id': instance.id,
      'startTime': _dateTimeToJson(instance.startTime),
      'endTime': _dateTimeToJson(instance.endTime),
    };

RehearsalVote _$RehearsalVoteFromJson(Map<String, dynamic> json) =>
    RehearsalVote(
      uid: json['uid'] as String? ?? '',
      answers:
          (json['answers'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          {},
      comment: json['comment'] as String?,
      updatedAt: _parseDateTime(json['updatedAt']),
    );

Map<String, dynamic> _$RehearsalVoteToJson(RehearsalVote instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'answers': instance.answers,
      'comment': instance.comment,
      'updatedAt': _dateTimeToJson(instance.updatedAt),
    };

Rehearsal _$RehearsalFromJson(Map<String, dynamic> json) => Rehearsal(
  id: json['id'] as String? ?? '',
  bandId: json['bandId'] as String? ?? '',
  createdBy: json['createdBy'] as String? ?? '',
  title: json['title'] as String? ?? '',
  description: json['description'] as String?,
  candidateSlots:
      (json['candidateSlots'] as List<dynamic>?)
          ?.map((e) => CandidateSlot.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
  requiredMemberUids:
      (json['requiredMemberUids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
  optionalMemberUids:
      (json['optionalMemberUids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
  setlistId: json['setlistId'] as String?,
  setlistScope: json['setlistScope'] as String?,
  location: json['location'] as String?,
  notes: json['notes'] as String?,
  status: json['status'] as String? ?? 'collecting',
  confirmedSlotId: json['confirmedSlotId'] as String?,
  createdAt: _parseDateTime(json['createdAt']),
  updatedAt: _parseDateTime(json['updatedAt']),
);

Map<String, dynamic> _$RehearsalToJson(Rehearsal instance) => <String, dynamic>{
  'id': instance.id,
  'bandId': instance.bandId,
  'createdBy': instance.createdBy,
  'title': instance.title,
  'description': instance.description,
  'candidateSlots': instance.candidateSlots.map((e) => e.toJson()).toList(),
  'durationMinutes': instance.durationMinutes,
  'requiredMemberUids': instance.requiredMemberUids,
  'optionalMemberUids': instance.optionalMemberUids,
  'setlistId': instance.setlistId,
  'setlistScope': instance.setlistScope,
  'location': instance.location,
  'notes': instance.notes,
  'status': instance.status,
  'confirmedSlotId': instance.confirmedSlotId,
  'createdAt': _dateTimeToJson(instance.createdAt),
  'updatedAt': _dateTimeToJson(instance.updatedAt),
};
