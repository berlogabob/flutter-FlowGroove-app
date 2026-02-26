import 'package:json_annotation/json_annotation.dart';

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
  final DateTime? eventDate;
  final String? eventLocation;
  @JsonKey(defaultValue: [])
  final List<String> songIds;
  final int? totalDuration;
  @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)
  final DateTime createdAt;
  @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)
  final DateTime updatedAt;

  Setlist({
    required this.id,
    required this.bandId,
    required this.name,
    this.description,
    this.eventDate,
    this.eventLocation,
    this.songIds = const [],
    this.totalDuration,
    required this.createdAt,
    required this.updatedAt,
  });

  Setlist copyWith({
    String? id,
    String? bandId,
    String? name,
    Object? description = _sentinel,
    Object? eventDate = _sentinel,
    Object? eventLocation = _sentinel,
    List<String>? songIds,
    Object? totalDuration = _sentinel,
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
      eventDate: eventDate == _sentinel
          ? this.eventDate
          : eventDate as DateTime?,
      eventLocation: eventLocation == _sentinel
          ? this.eventLocation
          : eventLocation as String?,
      songIds: songIds ?? this.songIds,
      totalDuration: totalDuration == _sentinel
          ? this.totalDuration
          : totalDuration as int?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => _$SetlistToJson(this);

  factory Setlist.fromJson(Map<String, dynamic> json) =>
      _$SetlistFromJson(json);

  String get formattedEventDate {
    if (eventDate == null) return '';
    return '${eventDate!.day.toString().padLeft(2, '0')}.${eventDate!.month.toString().padLeft(2, '0')}.${eventDate!.year}';
  }
}

DateTime _parseDateTime(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  return DateTime.parse(value as String);
}

String? _dateTimeToJson(DateTime? value) => value?.toIso8601String();
