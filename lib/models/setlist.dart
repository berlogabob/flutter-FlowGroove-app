import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';
import 'setlist_assignment.dart';
import 'band.dart';

part 'setlist.g.dart';

// Sentinel value to detect if a parameter was passed to copyWith
const Object _sentinel = _Sentinel();

class _Sentinel {
  const _Sentinel();
  @override
  String toString() => '_sentinel';
}

@JsonSerializable()
class Setlist {
  @JsonKey(defaultValue: '')
  final String id;
  @JsonKey(defaultValue: '')
  final String bandId;
  @JsonKey(defaultValue: '')
  final String name;
  final String? description;
  @JsonKey(fromJson: _parseTimestamp, toJson: _dateTimeToJson)
  final DateTime? eventDateTime;
  final String? eventLocation;
  @JsonKey(defaultValue: [])
  final List<String> songIds;
  final int? totalDuration;
  @JsonKey(
    defaultValue: {},
    fromJson: _assignmentsFromJson,
    toJson: _assignmentsToJson,
  )
  final Map<String, SetlistAssignment> assignments;
  @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)
  final DateTime createdAt;
  @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)
  final DateTime updatedAt;

  Setlist({
    required this.id,
    required this.bandId,
    required this.name,
    this.description,
    this.eventDateTime,
    this.eventLocation,
    this.songIds = const [],
    this.totalDuration,
    this.assignments = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  Setlist copyWith({
    String? id,
    String? bandId,
    String? name,
    Object? description = _sentinel,
    Object? eventDateTime = _sentinel,
    Object? eventLocation = _sentinel,
    List<String>? songIds,
    Object? totalDuration = _sentinel,
    Map<String, SetlistAssignment>? assignments,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Setlist(
      id: id ?? this.id,
      bandId: bandId ?? this.bandId,
      name: name ?? this.name,
      description: description == _sentinel
          ? this.description
          : description as String?,
      eventDateTime: eventDateTime == _sentinel
          ? this.eventDateTime
          : eventDateTime as DateTime?,
      eventLocation: eventLocation == _sentinel
          ? this.eventLocation
          : eventLocation as String?,
      songIds: songIds ?? this.songIds,
      totalDuration: totalDuration == _sentinel
          ? this.totalDuration
          : totalDuration as int?,
      assignments: assignments ?? this.assignments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => _$SetlistToJson(this);

  factory Setlist.fromJson(Map<String, dynamic> json) =>
      _$SetlistFromJson(json);

  String get formattedEventDate {
    if (eventDateTime == null) return '';
    return '${eventDateTime!.day.toString().padLeft(2, '0')}.${eventDateTime!.month.toString().padLeft(2, '0')}.${eventDateTime!.year}';
  }

  /// Get list of participants for this setlist based on band members and assignments.
  ///
  /// Returns a list of participant info including their role for this setlist.
  List<Map<String, String>> getParticipants(List<BandMember> bandMembers) {
    final participants = <Map<String, String>>[];

    for (final member in bandMembers) {
      final participant = <String, String>{
        'uid': member.uid,
        'name': member.displayName ?? member.email ?? 'Unknown',
        'role': member.role,
      };
      participants.add(participant);
    }

    return participants;
  }
}

DateTime _parseDateTime(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  try {
    if (value.runtimeType.toString() == 'Timestamp') {
      return (value as dynamic).toDate() as DateTime;
    }
  } catch (_) {}
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (_) {}
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  return DateTime.now();
}

DateTime? _parseTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  try {
    if (value.runtimeType.toString() == 'Timestamp') {
      return (value as dynamic).toDate() as DateTime;
    }
  } catch (_) {}
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  return null;
}

String? _dateTimeToJson(DateTime? value) => value?.toIso8601String();

Map<String, SetlistAssignment> _assignmentsFromJson(dynamic value) {
  if (value == null) return {};
  if (value is Map) {
    final result = <String, SetlistAssignment>{};
    for (final entry in value.entries) {
      final key = entry.key.toString();
      if (entry.value is Map) {
        result[key] = SetlistAssignment.fromJson(
          Map<String, dynamic>.from(entry.value),
        );
      } else {
        result[key] = SetlistAssignment(oderId: key);
      }
    }
    return result;
  }
  return {};
}

Map<String, dynamic> _assignmentsToJson(Map<String, SetlistAssignment> value) {
  return value.map((key, val) => MapEntry(key, val.toJson()));
}
