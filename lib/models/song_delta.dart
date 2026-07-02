import 'package:equatable/equatable.dart';

import 'beat_mode.dart';
import 'canonical_song.dart';
import 'link.dart';
import 'section.dart';
import 'song.dart';

/// Allowed owner-specific fields for linked song customizations.
class SongDeltaField {
  static const ourKey = 'ourKey';
  static const ourBPM = 'ourBPM';
  static const notes = 'notes';
  static const tags = 'tags';
  static const links = 'links';
  static const sections = 'sections';
  static const accentBeats = 'accentBeats';
  static const regularBeats = 'regularBeats';
  static const beatModes = 'beatModes';
  static const arrangementName = 'arrangementName';
  static const arrangementType = 'arrangementType';
  static const defaultTuningPresetId = 'defaultTuningPresetId';

  static const allowed = {
    ourKey,
    ourBPM,
    notes,
    tags,
    links,
    sections,
    accentBeats,
    regularBeats,
    beatModes,
    arrangementName,
    arrangementType,
    defaultTuningPresetId,
  };
}

/// Typed domain delta for user/band-specific song changes.
///
/// This is intentionally not a generic JSON Patch. It only permits fields the
/// app knows how to merge into a [Song] read model.
class SongDelta extends Equatable {

  SongDelta({Map<String, dynamic> values = const {}})
    : values = Map.unmodifiable(_sanitize(values));

  factory SongDelta.fromJson(Map<String, dynamic>? json) {
    return SongDelta(values: json ?? const {});
  }

  /// Builds a delta by comparing the editable song fields against canonical
  /// defaults.
  factory SongDelta.compute({
    required CanonicalSong canonical,
    required Song song,
    String? arrangementName,
    String? arrangementType,
  }) {
    final values = <String, dynamic>{};

    if (song.ourKey != canonical.baseKey) {
      values[SongDeltaField.ourKey] = song.ourKey;
    }
    if (song.ourBPM != canonical.baseBpm) {
      values[SongDeltaField.ourBPM] = song.ourBPM;
    }
    if ((song.notes ?? '').isNotEmpty) {
      values[SongDeltaField.notes] = song.notes;
    }
    if (song.tags.isNotEmpty) {
      values[SongDeltaField.tags] = song.tags;
    }
    if (!_jsonListEquals(
      _linksToJson(song.links),
      _linksToJson(canonical.baseLinks),
    )) {
      values[SongDeltaField.links] = song.links;
    }
    if (!_jsonListEquals(
      _sectionsToJson(song.sections),
      _sectionsToJson(canonical.baseSections),
    )) {
      values[SongDeltaField.sections] = song.sections;
    }
    if (song.accentBeats != canonical.baseAccentBeats) {
      values[SongDeltaField.accentBeats] = song.accentBeats;
    }
    if (song.regularBeats != canonical.baseRegularBeats) {
      values[SongDeltaField.regularBeats] = song.regularBeats;
    }
    if (!_jsonMapEquals(
      _beatModesToJson(song.beatModes),
      _beatModesToJson(canonical.baseBeatModes),
    )) {
      values[SongDeltaField.beatModes] = song.beatModes;
    }
    if (arrangementName != null && arrangementName.trim().isNotEmpty) {
      values[SongDeltaField.arrangementName] = arrangementName.trim();
    }
    if (arrangementType != null && arrangementType.trim().isNotEmpty) {
      values[SongDeltaField.arrangementType] = arrangementType.trim();
    }
    if ((song.defaultTuningPresetId ?? '').isNotEmpty) {
      values[SongDeltaField.defaultTuningPresetId] = song.defaultTuningPresetId;
    }

    return SongDelta(values: values);
  }
  final Map<String, dynamic> values;

  Map<String, dynamic> toJson() {
    return values.map((key, value) => MapEntry(key, _toJsonValue(value)));
  }

  bool has(String field) => values.containsKey(field);

  String? get ourKey => values[SongDeltaField.ourKey] as String?;
  int? get ourBPM => values[SongDeltaField.ourBPM] as int?;
  String? get notes => values[SongDeltaField.notes] as String?;

  List<String>? get tags {
    final raw = values[SongDeltaField.tags];
    if (raw == null) return null;
    return List<String>.from(raw as List);
  }

  List<Link>? get links {
    final raw = values[SongDeltaField.links];
    if (raw == null) return null;
    return List<Link>.from(raw as List);
  }

  List<Section>? get sections {
    final raw = values[SongDeltaField.sections];
    if (raw == null) return null;
    return List<Section>.from(raw as List);
  }

  int? get accentBeats => values[SongDeltaField.accentBeats] as int?;
  int? get regularBeats => values[SongDeltaField.regularBeats] as int?;

  List<List<BeatMode>>? get beatModes {
    final raw = values[SongDeltaField.beatModes];
    if (raw == null) return null;
    return (raw as List)
        .map((row) => List<BeatMode>.from(row as List))
        .toList();
  }

  String? get arrangementName =>
      values[SongDeltaField.arrangementName] as String?;
  String? get arrangementType =>
      values[SongDeltaField.arrangementType] as String?;
  String? get defaultTuningPresetId =>
      values[SongDeltaField.defaultTuningPresetId] as String?;

  bool get isEmpty => values.isEmpty;
  bool get isNotEmpty => values.isNotEmpty;

  /// Applies this delta to a canonical song and returns the existing app read
  /// model. The library document id remains the user-facing song id.
  Song applyTo({
    required CanonicalSong canonical,
    required String librarySongId,
    String? bandId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? originalOwnerId,
    String? originalSongId,
    String? contributedBy,
    bool isCopy = false,
    DateTime? contributedAt,
  }) {
    return Song(
      id: librarySongId,
      title: canonical.title,
      artist: canonical.artist,
      originalKey: canonical.baseKey,
      originalBPM: canonical.baseBpm,
      ourKey: has(SongDeltaField.ourKey) ? ourKey : canonical.baseKey,
      ourBPM: has(SongDeltaField.ourBPM) ? ourBPM : canonical.baseBpm,
      links: links ?? canonical.baseLinks,
      notes: has(SongDeltaField.notes) ? notes : null,
      defaultTuningPresetId: has(SongDeltaField.defaultTuningPresetId)
          ? defaultTuningPresetId
          : null,
      tags: tags ?? const [],
      bandId: bandId,
      createdAt: createdAt ?? canonical.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      originalOwnerId: originalOwnerId,
      originalSongId: originalSongId,
      contributedBy: contributedBy,
      isCopy: isCopy,
      contributedAt: contributedAt,
      accentBeats: accentBeats ?? canonical.baseAccentBeats,
      regularBeats: regularBeats ?? canonical.baseRegularBeats,
      beatModes: beatModes ?? canonical.baseBeatModes,
      sections: sections ?? canonical.baseSections,
      spotifyId: canonical.spotifyId,
      musicbrainzId: canonical.musicBrainzId,
      isrc: canonical.isrc,
      normalizedTitle: canonical.normalizedTitle,
      normalizedArtist: canonical.normalizedArtist,
      durationMs: canonical.durationMs,
      album: canonical.album,
      canonicalSongId: canonical.id,
      isFromMusicBrainz: canonical.hasMusicBrainzData,
    );
  }

  @override
  List<Object?> get props => [values];
}

Map<String, dynamic> _sanitize(Map<String, dynamic> input) {
  final result = <String, dynamic>{};
  for (final entry in input.entries) {
    if (!SongDeltaField.allowed.contains(entry.key)) continue;
    result[entry.key] = _normalizeValue(entry.key, entry.value);
  }
  return result;
}

dynamic _normalizeValue(String field, dynamic value) {
  switch (field) {
    case SongDeltaField.tags:
      if (value == null) return null;
      return List<String>.from(value as List);
    case SongDeltaField.links:
      if (value == null) return null;
      if (value is List<Link>) return value;
      return (value as List)
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => Link.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    case SongDeltaField.sections:
      if (value == null) return null;
      if (value is List<Section>) return value;
      return (value as List)
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => Section.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    case SongDeltaField.beatModes:
      return _beatModesFromJson(value);
    default:
      return value;
  }
}

dynamic _toJsonValue(dynamic value) {
  if (value is List<Link>) return _linksToJson(value);
  if (value is List<Section>) return _sectionsToJson(value);
  if (value is List<List<BeatMode>>) return _beatModesToJson(value);
  return value;
}

List<Map<String, dynamic>> _linksToJson(List<Link> links) {
  return links.map((link) => link.toJson()).toList();
}

List<Map<String, dynamic>> _sectionsToJson(List<Section> sections) {
  return sections.map((section) => section.toJson()).toList();
}

List<List<BeatMode>> _beatModesFromJson(dynamic value) {
  if (value == null) return [];
  if (value is List<List<BeatMode>>) return value;
  if (value is List) {
    return value.map((row) {
      if (row is! List) return <BeatMode>[];
      return row.map((modeValue) {
        if (modeValue is BeatMode) return modeValue;
        if (modeValue is String) {
          return BeatMode.values.firstWhere(
            (mode) => mode.name == modeValue,
            orElse: () => BeatMode.normal,
          );
        }
        return BeatMode.normal;
      }).toList();
    }).toList();
  }
  if (value is Map) {
    if (value.isEmpty) return [];
    var maxBeat = 0;
    var maxSubdivision = 0;
    value.forEach((key, _) {
      final parts = key.toString().split('-');
      if (parts.length != 2) return;
      maxBeat = _max(maxBeat, int.tryParse(parts[0]) ?? 0);
      maxSubdivision = _max(maxSubdivision, int.tryParse(parts[1]) ?? 0);
    });
    final result = List.generate(
      maxBeat + 1,
      (_) => List.filled(maxSubdivision + 1, BeatMode.normal),
    );
    value.forEach((key, modeValue) {
      final parts = key.toString().split('-');
      if (parts.length != 2) return;
      final beat = int.tryParse(parts[0]) ?? 0;
      final subdivision = int.tryParse(parts[1]) ?? 0;
      result[beat][subdivision] = BeatMode.values.firstWhere(
        (mode) => mode.name == modeValue,
        orElse: () => BeatMode.normal,
      );
    });
    return result;
  }
  return [];
}

Map<String, String> _beatModesToJson(List<List<BeatMode>> value) {
  final result = <String, String>{};
  for (var beat = 0; beat < value.length; beat++) {
    for (var subdivision = 0; subdivision < value[beat].length; subdivision++) {
      result['$beat-$subdivision'] = value[beat][subdivision].name;
    }
  }
  return result;
}

bool _jsonListEquals(
  List<Map<String, dynamic>> a,
  List<Map<String, dynamic>> b,
) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!_jsonMapEquals(a[i], b[i])) return false;
  }
  return true;
}

bool _jsonMapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key)) return false;
    if (a[key] != b[key]) return false;
  }
  return true;
}

int _max(int a, int b) => a > b ? a : b;
