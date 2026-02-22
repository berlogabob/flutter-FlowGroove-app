import 'package:json_annotation/json_annotation.dart';
import 'link.dart';

part 'song.g.dart';

// Sentinel value to detect if a parameter was passed to copyWith
const Object _sentinel = _Sentinel();

class _Sentinel {
  const _Sentinel();
  @override
  String toString() => '_sentinel';
}

@JsonSerializable()
class Song {
  @JsonKey(defaultValue: '')
  final String id;
  @JsonKey(defaultValue: '')
  final String title;
  @JsonKey(defaultValue: '')
  final String artist;
  final String? originalKey;
  final int? originalBPM;
  final String? ourKey;
  final int? ourBPM;
  @JsonKey(defaultValue: [], fromJson: _linksFromJson, toJson: _linksToJson)
  final List<Link> links;
  final String? notes;
  @JsonKey(defaultValue: [])
  final List<String> tags;
  final String? bandId;
  final String? spotifyUrl;
  @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)
  final DateTime createdAt;
  @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)
  final DateTime updatedAt;

  // NEW: Sharing fields for copying songs from personal banks to band banks
  final String? originalOwnerId; // User who created original song
  final String? contributedBy; // User who added to band
  @JsonKey(defaultValue: false)
  final bool isCopy; // True if this is a band's copy
  @JsonKey(fromJson: _parseNullableDateTime, toJson: _dateTimeToJson)
  final DateTime? contributedAt; // When added to band

  Song({
    required this.id,
    required this.title,
    required this.artist,
    this.originalKey,
    this.originalBPM,
    this.ourKey,
    this.ourBPM,
    this.links = const [],
    this.notes,
    this.tags = const [],
    this.bandId,
    this.spotifyUrl,
    required this.createdAt,
    required this.updatedAt,
    this.originalOwnerId,
    this.contributedBy,
    this.isCopy = false,
    this.contributedAt,
  });

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    Object? originalKey = _sentinel,
    Object? originalBPM = _sentinel,
    Object? ourKey = _sentinel,
    Object? ourBPM = _sentinel,
    List<Link>? links,
    Object? notes = _sentinel,
    List<String>? tags,
    Object? bandId = _sentinel,
    Object? spotifyUrl = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? originalOwnerId = _sentinel,
    Object? contributedBy = _sentinel,
    Object? isCopy = _sentinel,
    Object? contributedAt = _sentinel,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      originalKey: originalKey == _sentinel
          ? this.originalKey
          : originalKey as String?,
      originalBPM: originalBPM == _sentinel
          ? this.originalBPM
          : originalBPM as int?,
      ourKey: ourKey == _sentinel ? this.ourKey : ourKey as String?,
      ourBPM: ourBPM == _sentinel ? this.ourBPM : ourBPM as int?,
      links: links ?? this.links,
      notes: notes == _sentinel ? this.notes : notes as String?,
      tags: tags ?? this.tags,
      bandId: bandId == _sentinel ? this.bandId : bandId as String?,
      spotifyUrl: spotifyUrl == _sentinel
          ? this.spotifyUrl
          : spotifyUrl as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      originalOwnerId: originalOwnerId == _sentinel
          ? this.originalOwnerId
          : originalOwnerId as String?,
      contributedBy: contributedBy == _sentinel
          ? this.contributedBy
          : contributedBy as String?,
      isCopy: isCopy == _sentinel ? this.isCopy : isCopy as bool,
      contributedAt: contributedAt == _sentinel
          ? this.contributedAt
          : contributedAt as DateTime?,
    );
  }

  Map<String, dynamic> toJson() => _$SongToJson(this);

  factory Song.fromJson(Map<String, dynamic> json) => _$SongFromJson(json);
}

DateTime _parseDateTime(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  return DateTime.parse(value as String);
}

DateTime? _parseNullableDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.parse(value as String);
}

String? _dateTimeToJson(DateTime? value) => value?.toIso8601String();

List<Link> _linksFromJson(dynamic value) {
  if (value == null) return [];
  if (value is List<Link>) return value;
  return (value as List<dynamic>)
      .map((e) => Link.fromJson(e as Map<String, dynamic>))
      .toList();
}

List<Map<String, dynamic>> _linksToJson(List<Link> links) {
  return links.map((l) => l.toJson()).toList();
}
