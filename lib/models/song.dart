import 'package:json_annotation/json_annotation.dart';
import 'link.dart';
import 'beat_mode.dart';
import 'section.dart';

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

  // Metronome settings
  @JsonKey(defaultValue: 4)
  final int accentBeats; // Beats per measure (top row, first number)
  @JsonKey(defaultValue: 1)
  final int regularBeats; // Subdivisions per beat (bottom row)
  @JsonKey(
    defaultValue: [],
    fromJson: _beatModesFromJson,
    toJson: _beatModesToJson,
  )
  final List<List<BeatMode>> beatModes; // 2D: beats × subdivisions (independent modes)

  /// Song structure sections.
  @JsonKey(
    defaultValue: [],
    fromJson: _sectionsFromJson,
    toJson: _sectionsToJson,
  )
  final List<Section> sections;

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
    this.accentBeats = 4,
    this.regularBeats = 1,
    this.beatModes = const [],
    this.sections = const [],
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
    int? accentBeats,
    int? regularBeats,
    List<List<BeatMode>>? beatModes,
    List<Section>? sections,
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
      accentBeats: accentBeats ?? this.accentBeats,
      regularBeats: regularBeats ?? this.regularBeats,
      beatModes: beatModes ?? this.beatModes,
      sections: sections ?? this.sections,
    );
  }

  Map<String, dynamic> toJson() => _$SongToJson(this);

  factory Song.fromJson(Map<String, dynamic> json) => _$SongFromJson(json);
}

// Helper methods for BeatMode serialization
List<List<BeatMode>> _beatModesFromJson(dynamic value) {
  if (value == null) return [];

  // Support both nested arrays (legacy) and map format (new)
  if (value is List) {
    return value.map((beatRow) {
      if (beatRow is List) {
        return beatRow.map((modeValue) {
          if (modeValue is String) {
            return BeatMode.values.firstWhere(
              (mode) => mode.name == modeValue,
              orElse: () => BeatMode.normal,
            );
          }
          return BeatMode.normal;
        }).toList();
      }
      return <BeatMode>[];
    }).toList();
  }

  // Support map format: {"0-0": "accent", "0-1": "normal", ...}
  if (value is Map) {
    final result = <List<BeatMode>>[];

    // Find max dimensions
    int maxBeat = 0;
    int maxSubdivision = 0;
    value.forEach((key, modeValue) {
      final parts = key.toString().split('-');
      if (parts.length == 2) {
        final beat = int.tryParse(parts[0]) ?? 0;
        final subdivision = int.tryParse(parts[1]) ?? 0;
        if (beat > maxBeat) maxBeat = beat;
        if (subdivision > maxSubdivision) maxSubdivision = subdivision;
      }
    });

    // Initialize grid
    for (int i = 0; i <= maxBeat; i++) {
      final row = <BeatMode>[];
      for (int j = 0; j <= maxSubdivision; j++) {
        row.add(BeatMode.normal);
      }
      result.add(row);
    }

    // Fill values
    value.forEach((key, modeValue) {
      final parts = key.toString().split('-');
      if (parts.length == 2) {
        final beat = int.tryParse(parts[0]) ?? 0;
        final subdivision = int.tryParse(parts[1]) ?? 0;
        if (beat < result.length && subdivision < result[beat].length) {
          result[beat][subdivision] = BeatMode.values.firstWhere(
            (mode) => mode.name == modeValue,
            orElse: () => BeatMode.normal,
          );
        }
      }
    });

    return result;
  }

  return [];
}

Map<String, String> _beatModesToJson(List<List<BeatMode>> value) {
  final result = <String, String>{};
  for (int i = 0; i < value.length; i++) {
    for (int j = 0; j < value[i].length; j++) {
      result['$i-$j'] = value[i][j].name;
    }
  }
  return result;
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

List<Section> _sectionsFromJson(dynamic value) {
  if (value == null) return [];
  if (value is List<Section>) return value;
  return (value as List<dynamic>)
      .map((e) => Section.fromJson(e as Map<String, dynamic>))
      .toList();
}

List<Map<String, dynamic>> _sectionsToJson(List<Section> sections) {
  return sections.map((s) => s.toJson()).toList();
}
