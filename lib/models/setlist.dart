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

class SetlistItem {
  final String id;
  final String songId;
  final String? tuningPresetId;

  const SetlistItem({
    required this.id,
    required this.songId,
    this.tuningPresetId,
  });

  SetlistItem copyWith({String? id, String? songId, String? tuningPresetId}) {
    return SetlistItem(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      tuningPresetId: tuningPresetId ?? this.tuningPresetId,
    );
  }

  factory SetlistItem.fromJson(Map<String, dynamic> json) => SetlistItem(
    id: json['id'] as String? ?? '',
    songId: json['songId'] as String? ?? '',
    tuningPresetId: json['tuningPresetId'] as String?,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'songId': songId,
    if (tuningPresetId != null) 'tuningPresetId': tuningPresetId,
  };
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
  @JsonKey(defaultValue: [], fromJson: _itemsFromJson, toJson: _itemsToJson)
  final List<SetlistItem> items;
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
    this.items = const [],
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
    List<SetlistItem>? items,
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
      items: items ?? this.items,
      totalDuration: totalDuration == _sentinel
          ? this.totalDuration
          : totalDuration as int?,
      assignments: assignments ?? this.assignments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  List<SetlistItem> get effectiveItems {
    if (items.isNotEmpty) return items;
    return List.generate(
      songIds.length,
      (index) => SetlistItem(
        id: 'legacy-$index-${songIds[index]}',
        songId: songIds[index],
      ),
    );
  }

  String? tuningPresetIdForItem(String itemId) {
    for (final item in effectiveItems) {
      if (item.id == itemId) return item.tuningPresetId;
    }
    return null;
  }

  Setlist withItemTuningPreset(String itemId, String? presetId) {
    final updatedItems = effectiveItems
        .map(
          (item) => item.id == itemId
              ? SetlistItem(
                  id: item.id,
                  songId: item.songId,
                  tuningPresetId: presetId,
                )
              : item,
        )
        .toList();
    return copyWith(
      items: updatedItems,
      songIds: updatedItems.map((item) => item.songId).toList(),
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final json = _$SetlistToJson(this);
    final syncedItems = effectiveItems;
    json['items'] = _itemsToJson(syncedItems);
    json['songIds'] = syncedItems.map((item) => item.songId).toList();
    return json;
  }

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
  debugPrint(
    '⚠️ Invalid date format in Setlist: $value (${value.runtimeType})',
  );
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
      if (entry.value is Map<dynamic, dynamic>) {
        final mapValue = entry.value as Map<dynamic, dynamic>;
        result[key] = SetlistAssignment.fromJson(
          Map<String, dynamic>.from(mapValue),
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

List<SetlistItem> _itemsFromJson(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map<dynamic, dynamic>>()
      .map((item) => SetlistItem.fromJson(Map<String, dynamic>.from(item)))
      .where((item) => item.songId.isNotEmpty)
      .toList();
}

List<Map<String, dynamic>> _itemsToJson(List<SetlistItem> value) {
  return value.map((item) => item.toJson()).toList();
}
