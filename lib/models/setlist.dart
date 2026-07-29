import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

import 'band.dart';
import 'event_kit.dart';
import 'setlist_assignment.dart';

part 'setlist.g.dart';

// Sentinel value to detect if a parameter was passed to copyWith
const Object _sentinel = _Sentinel();

class _Sentinel {
  const _Sentinel();
  @override
  String toString() => '_sentinel';
}

/// An ordered entry in a setlist: either a song (`type == 'song'`, carries a
/// [songId]) or a break/section divider (`type == 'break'`, carries a
/// [breakType] + optional [breakLabel] instead of a song). Breaks visually
/// divide a set (guest sets, an intermission, an encore/backup pool) the way a
/// real gig setlist does.
class SetlistItem {
  const SetlistItem({
    required this.id,
    this.songId = '',
    this.tuningPresetId,
    this.type = itemTypeSong,
    this.breakType,
    this.breakLabel,
    this.performerIds = const [],
  });

  /// A break/divider entry. [breakType] is a SetlistBreakType id; [label] is
  /// an optional custom name (e.g. "EUSTACE"), falling back to the type's
  /// default label when null/empty.
  factory SetlistItem.breakItem({
    required String id,
    required String breakType,
    String? label,
  }) => SetlistItem(
    id: id,
    type: itemTypeBreak,
    breakType: breakType,
    breakLabel: label,
  );

  factory SetlistItem.fromJson(Map<String, dynamic> json) => SetlistItem(
    id: json['id'] as String? ?? '',
    songId: json['songId'] as String? ?? '',
    tuningPresetId: json['tuningPresetId'] as String?,
    type: json['type'] as String? ?? itemTypeSong,
    breakType: json['breakType'] as String?,
    breakLabel: json['breakLabel'] as String?,
    performerIds:
        (json['performerIds'] as List?)?.whereType<String>().toList() ??
        const [],
  );

  static const String itemTypeSong = 'song';
  static const String itemTypeBreak = 'break';

  final String id;
  final String songId;
  final String? tuningPresetId;

  /// `'song'` or `'break'`.
  final String type;

  /// For break items: a SetlistBreakType id. Null for songs.
  final String? breakType;

  /// For break items: optional custom label (e.g. a guest name). Null for songs.
  final String? breakLabel;

  /// Who plays this song — `EventPerson.id`s from the setlist's Event Kit
  /// roster. Empty means "everyone / not specified".
  final List<String> performerIds;

  bool get isBreak => type == itemTypeBreak;

  SetlistItem copyWith({
    String? id,
    String? songId,
    String? tuningPresetId,
    String? type,
    String? breakType,
    String? breakLabel,
    List<String>? performerIds,
    bool clearTuningPreset = false,
    bool clearBreakLabel = false,
  }) {
    return SetlistItem(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      tuningPresetId: clearTuningPreset
          ? null
          : (tuningPresetId ?? this.tuningPresetId),
      type: type ?? this.type,
      breakType: breakType ?? this.breakType,
      // Without the explicit clear, erasing a custom label would silently
      // restore the old one — a null here can't be told from "unchanged".
      breakLabel: clearBreakLabel ? null : (breakLabel ?? this.breakLabel),
      performerIds: performerIds ?? this.performerIds,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'songId': songId,
    if (tuningPresetId != null) 'tuningPresetId': tuningPresetId,
    if (type != itemTypeSong) 'type': type,
    if (breakType != null) 'breakType': breakType,
    if (breakLabel != null) 'breakLabel': breakLabel,
    if (performerIds.isNotEmpty) 'performerIds': performerIds,
  };
}

@JsonSerializable()
class Setlist {
  Setlist({
    required this.id,
    required this.bandId,
    required this.name,
    required this.createdAt, required this.updatedAt, this.description,
    this.eventDateTime,
    this.eventLocation,
    this.songIds = const [],
    this.items = const [],
    this.totalDuration,
    this.assignments = const {},
    this.eventKit,
  });

  factory Setlist.fromJson(Map<String, dynamic> json) =>
      _$SetlistFromJson(json);

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

  /// Event Kit (#52): stage plot, crew/guests, rider — inline map, nullable
  /// for every pre-existing doc.
  @JsonKey(fromJson: _eventKitFromJson, toJson: _eventKitToJson)
  final EventKit? eventKit;
  @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)
  final DateTime createdAt;
  @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)
  final DateTime updatedAt;

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
    Object? eventKit = _sentinel,
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
      eventKit: eventKit == _sentinel ? this.eventKit : eventKit as EventKit?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    final json = _$SetlistToJson(this);
    final syncedItems = effectiveItems;
    json['items'] = _itemsToJson(syncedItems);
    // songIds mirrors song items only — break dividers are not songs.
    json['songIds'] = syncedItems
        .where((item) => !item.isBreak && item.songId.isNotEmpty)
        .map((item) => item.songId)
        .toList();
    return json;
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
    // copyWith, not a fresh SetlistItem: a rebuilt item used to drop the
    // break type/label and the performers. songIds is rebuilt in toJson().
    final updatedItems = effectiveItems
        .map(
          (item) => item.id == itemId
              ? item.copyWith(
                  tuningPresetId: presetId,
                  clearTuningPreset: presetId == null,
                )
              : item,
        )
        .toList();
    return copyWith(items: updatedItems, updatedAt: DateTime.now());
  }

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
      // Keep song items that resolve to a songId, plus break/divider items.
      .where((item) => item.songId.isNotEmpty || item.isBreak)
      .toList();
}

List<Map<String, dynamic>> _itemsToJson(List<SetlistItem> value) {
  return value.map((item) => item.toJson()).toList();
}

EventKit? _eventKitFromJson(dynamic value) => value is Map
    ? EventKit.fromJson(Map<String, dynamic>.from(value))
    : null;

Map<String, dynamic>? _eventKitToJson(EventKit? kit) => kit?.toJson();
