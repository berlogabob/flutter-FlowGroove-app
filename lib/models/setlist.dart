import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
  debugPrint(
    '🔍 _parseDateTime called with: $value (type: ${value.runtimeType})',
  );
  if (value == null) return DateTime.now();
  if (value is DateTime) {
    debugPrint('   → Is DateTime');
    return value;
  }
  if (value is Timestamp) {
    debugPrint('   → Is Timestamp, converting');
    return value.toDate();
  }
  try {
    debugPrint('   → Parsing as String');
    return DateTime.parse(value as String);
  } catch (e) {
    debugPrint('   → Failed to parse: $e');
    return DateTime.now();
  }
}

DateTime? _parseTimestamp(dynamic value) {
  debugPrint(
    '🔍 _parseTimestamp called with: $value (type: ${value.runtimeType})',
  );
  if (value == null) {
    debugPrint('   → Is null');
    return null;
  }
  if (value is DateTime) {
    debugPrint('   → Is DateTime');
    return value;
  }
  if (value is Timestamp) {
    debugPrint('   → Is Timestamp, converting');
    return value.toDate();
  }
  try {
    debugPrint('   → Parsing as String');
    return DateTime.parse(value as String);
  } catch (e) {
    debugPrint('   → Failed to parse: $e');
    return null;
  }
}

DateTime? _parseNullableDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) {
    // Try ISO format first
    final result = DateTime.tryParse(value);
    if (result != null) return result;

    // Log problematic values for debugging
    debugPrint('⚠️ Invalid date format detected: "$value"');
    debugPrint('   Type: ${value.runtimeType}');
    debugPrint('   Length: ${value.length}');

    // Try to handle common formats
    // Format: "dd-MM" or "dd-yy"
    if (value.contains('-')) {
      final parts = value.split('-');
      if (parts.length == 2) {
        try {
          final day = int.tryParse(parts[0]) ?? 1;
          final monthOrYear = int.tryParse(parts[1]) ?? 1;

          // If second part is < 13, it's likely a month (dd-MM format)
          // Otherwise it's likely a year (dd-yy format)
          if (monthOrYear < 13) {
            debugPrint(
              '   → Interpreting as dd-MM: day=$day, month=$monthOrYear',
            );
            return DateTime(DateTime.now().year, monthOrYear, day);
          } else {
            debugPrint(
              '   → Interpreting as dd-yy: day=$day, year=20$monthOrYear',
            );
            return DateTime(2000 + monthOrYear, 1, day);
          }
        } catch (e) {
          debugPrint('   → Failed to parse: $e');
        }
      }
    }

    return null;
  }
  return null;
}

// Parse string field (legacy support)
String? _parseStringField(dynamic value) {
  if (value == null) return null;
  return value.toString();
}

String? _stringFieldToJson(dynamic value) {
  if (value == null) return null;
  return value.toString();
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
