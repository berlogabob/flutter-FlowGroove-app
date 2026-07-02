import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'rehearsal.g.dart';

// Sentinel value to detect if a parameter was passed to copyWith (see band.dart).
const Object _sentinel = _Sentinel();

class _Sentinel {
  const _Sentinel();
  @override
  String toString() => '_sentinel';
}

/// A proposed time window members vote on.
@JsonSerializable()
class CandidateSlot {
  CandidateSlot({
    required this.id,
    required this.startTime,
    required this.endTime,
  });

  factory CandidateSlot.fromJson(Map<String, dynamic> json) =>
      _$CandidateSlotFromJson(json);

  @JsonKey(defaultValue: '')
  final String id;
  @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)
  final DateTime startTime;
  @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)
  final DateTime endTime;

  Map<String, dynamic> toJson() => _$CandidateSlotToJson(this);
}

/// A single member's availability answers for one rehearsal proposal.
/// Stored at bands/{bandId}/rehearsals/{rehearsalId}/votes/{uid} (docId == uid).
@JsonSerializable()
class RehearsalVote {
  RehearsalVote({
    required this.uid,
    this.answers = const {},
    this.comment,
    required this.updatedAt,
  });

  factory RehearsalVote.fromJson(Map<String, dynamic> json) =>
      _$RehearsalVoteFromJson(json);

  static const String answerCan = 'can';
  static const String answerMaybe = 'maybe';
  static const String answerCant = 'cant';

  @JsonKey(defaultValue: '')
  final String uid;

  /// slotId -> one of [answerCan], [answerMaybe], [answerCant].
  @JsonKey(defaultValue: {})
  final Map<String, String> answers;
  final String? comment;
  @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => _$RehearsalVoteToJson(this);
}

/// A rehearsal proposal that grows into a confirmed event (single merged
/// lifecycle: collecting -> confirmed -> done/cancelled). Stored at
/// bands/{bandId}/rehearsals/{rehearsalId}, mirroring band setlists.
// explicitToJson: candidateSlots must serialize to maps, or Firestore
// rejects the write with "Invalid argument: Instance of 'CandidateSlot'".
@JsonSerializable(explicitToJson: true)
class Rehearsal {
  Rehearsal({
    required this.id,
    required this.bandId,
    required this.createdBy,
    required this.title,
    this.description,
    this.candidateSlots = const [],
    this.durationMinutes,
    this.requiredMemberUids = const [],
    this.optionalMemberUids = const [],
    this.setlistId,
    this.setlistScope,
    this.location,
    this.notes,
    this.status = statusCollecting,
    this.confirmedSlotId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Rehearsal.fromJson(Map<String, dynamic> json) =>
      _$RehearsalFromJson(json);

  static const String statusCollecting = 'collecting';
  static const String statusConfirmed = 'confirmed';
  static const String statusCancelled = 'cancelled';
  static const String statusDone = 'done';

  static const String scopePersonal = 'personal';
  static const String scopeBand = 'band';

  @JsonKey(defaultValue: '')
  final String id;
  @JsonKey(defaultValue: '')
  final String bandId;
  @JsonKey(defaultValue: '')
  final String createdBy;
  @JsonKey(defaultValue: '')
  final String title;
  final String? description;
  @JsonKey(defaultValue: [])
  final List<CandidateSlot> candidateSlots;
  final int? durationMinutes;
  @JsonKey(defaultValue: [])
  final List<String> requiredMemberUids;
  @JsonKey(defaultValue: [])
  final List<String> optionalMemberUids;
  final String? setlistId;
  final String? setlistScope; // scopePersonal | scopeBand
  final String? location;
  final String? notes;
  @JsonKey(defaultValue: statusCollecting)
  final String status;
  final String? confirmedSlotId;
  @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)
  final DateTime createdAt;
  @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)
  final DateTime updatedAt;

  /// The chosen slot once confirmed, or null.
  CandidateSlot? get confirmedSlot {
    if (confirmedSlotId == null) return null;
    for (final s in candidateSlots) {
      if (s.id == confirmedSlotId) return s;
    }
    return null;
  }

  Rehearsal copyWith({
    String? id,
    String? bandId,
    String? createdBy,
    String? title,
    Object? description = _sentinel,
    List<CandidateSlot>? candidateSlots,
    Object? durationMinutes = _sentinel,
    List<String>? requiredMemberUids,
    List<String>? optionalMemberUids,
    Object? setlistId = _sentinel,
    Object? setlistScope = _sentinel,
    Object? location = _sentinel,
    Object? notes = _sentinel,
    String? status,
    Object? confirmedSlotId = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Rehearsal(
      id: id ?? this.id,
      bandId: bandId ?? this.bandId,
      createdBy: createdBy ?? this.createdBy,
      title: title ?? this.title,
      description: description == _sentinel
          ? this.description
          : description as String?,
      candidateSlots: candidateSlots ?? this.candidateSlots,
      durationMinutes: durationMinutes == _sentinel
          ? this.durationMinutes
          : durationMinutes as int?,
      requiredMemberUids: requiredMemberUids ?? this.requiredMemberUids,
      optionalMemberUids: optionalMemberUids ?? this.optionalMemberUids,
      setlistId: setlistId == _sentinel ? this.setlistId : setlistId as String?,
      setlistScope: setlistScope == _sentinel
          ? this.setlistScope
          : setlistScope as String?,
      location: location == _sentinel ? this.location : location as String?,
      notes: notes == _sentinel ? this.notes : notes as String?,
      status: status ?? this.status,
      confirmedSlotId: confirmedSlotId == _sentinel
          ? this.confirmedSlotId
          : confirmedSlotId as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => _$RehearsalToJson(this);
}

DateTime _parseDateTime(Object? value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  try {
    if (value is String) return DateTime.parse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  } catch (e) {
    debugPrint('⚠️ Invalid date format in Rehearsal: $value - $e');
  }
  return DateTime.now();
}

String? _dateTimeToJson(DateTime? value) => value?.toIso8601String();
