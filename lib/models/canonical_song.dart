import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

import 'beat_mode.dart';
import 'link.dart';
import 'section.dart';

part 'canonical_song.g.dart';

/// Represents a canonical song - the global source of truth for a song.
///
/// This is used to link multiple arrangements/versions of the same song
/// across different users and bands. Data is typically sourced from
/// MusicBrainz or created manually when no MusicBrainz match exists.
///
/// Example: "Bohemian Rhapsody" by Queen would have one CanonicalSong,
/// while multiple users/bands have their own Song arrangements linked to it.
@JsonSerializable()
class CanonicalSong extends Equatable {
  CanonicalSong({
    required this.id,
    required this.title,
    required this.artist,
    this.artists = const [],
    this.album,
    this.releaseYear,
    this.durationMs,
    this.isrc,
    this.spotifyId,
    this.musicBrainzId,
    this.musicBrainzWorkId,
    this.iswc,
    this.normalizedTitle,
    this.normalizedArtist,
    this.genres = const [],
    this.disambiguation,
    this.schemaVersion = 1,
    this.canonicalRevision = 1,
    this.source = 'manual',
    this.status = 'active',
    this.createdBy,
    this.baseKey,
    this.baseBpm,
    this.baseSections = const [],
    this.baseAccentBeats = 4,
    this.baseRegularBeats = 1,
    this.baseBeatModes = const [],
    this.baseLinks = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory CanonicalSong.fromJson(Map<String, dynamic> json) =>
      _$CanonicalSongFromJson(json);

  /// Create a CanonicalSong from MusicBrainz data
  factory CanonicalSong.fromMusicBrainz({
    required String title,
    required String artist,
    String? musicBrainzId,
    String? musicBrainzWorkId,
    int? durationMs,
    String? isrc,
    List<String>? artists,
    String? disambiguation,
  }) {
    return CanonicalSong(
      id: musicBrainzId ?? const Uuid().v4(),
      title: title.trim(),
      artist: artist.trim(),
      artists: artists ?? [artist.trim()],
      musicBrainzId: musicBrainzId,
      musicBrainzWorkId: musicBrainzWorkId,
      durationMs: durationMs,
      isrc: isrc,
      disambiguation: disambiguation,
      normalizedTitle: title.toLowerCase().trim(),
      normalizedArtist: artist.toLowerCase().trim(),
      source: 'musicbrainz',
    );
  }

  /// Create a new CanonicalSong manually (no MusicBrainz)
  factory CanonicalSong.manual({
    required String title,
    required String artist,
    String? album,
    int? releaseYear,
    List<String>? genres,
  }) {
    return CanonicalSong(
      id: const Uuid().v4(),
      title: title.trim(),
      artist: artist.trim(),
      album: album?.trim(),
      releaseYear: releaseYear,
      genres: genres ?? [],
      normalizedTitle: title.toLowerCase().trim(),
      normalizedArtist: artist.toLowerCase().trim(),
    );
  }

  /// Unique identifier (UUID or MusicBrainz ID)
  final String id;

  /// Song title (canonical form)
  final String title;

  /// Primary artist/band name
  final String artist;

  /// All artists (featuring, collaborators, etc.)
  @JsonKey(defaultValue: [])
  final List<String> artists;

  /// Album name (if applicable)
  final String? album;

  /// Release year
  final int? releaseYear;

  /// Duration in milliseconds
  final int? durationMs;

  /// ISRC (International Standard Recording Code)
  final String? isrc;

  /// Spotify track ID
  final String? spotifyId;

  /// MusicBrainz Recording ID
  final String? musicBrainzId;

  /// MusicBrainz Work ID (the composition, not recording)
  final String? musicBrainzWorkId;

  /// ISWC (International Standard Musical Work Code)
  final String? iswc;

  /// Normalized title for search (lowercase, trimmed)
  final String? normalizedTitle;

  /// Normalized artist for search
  final String? normalizedArtist;

  /// Genres/tags
  @JsonKey(defaultValue: [])
  final List<String> genres;

  /// Disambiguation (e.g., "live", "acoustic version")
  final String? disambiguation;

  /// Schema version for forward-compatible catalog records.
  @JsonKey(defaultValue: 1)
  final int schemaVersion;

  /// Monotonic revision of this canonical record.
  @JsonKey(defaultValue: 1)
  final int canonicalRevision;

  /// Source of this canonical record: manual, musicbrainz, spotify, import.
  @JsonKey(defaultValue: 'manual')
  final String source;

  /// Catalog status: active, merged, hidden, pending_review.
  @JsonKey(defaultValue: 'active')
  final String status;

  /// User/admin/service that created this catalog entry, when known.
  final String? createdBy;

  /// Canonical/default key, if known.
  final String? baseKey;

  /// Canonical/default tempo, if known.
  final int? baseBpm;

  /// Canonical/default structure map.
  @JsonKey(
    defaultValue: [],
    fromJson: _sectionsFromJson,
    toJson: _sectionsToJson,
  )
  final List<Section> baseSections;

  /// Canonical/default metronome beats per measure.
  @JsonKey(defaultValue: 4)
  final int baseAccentBeats;

  /// Canonical/default metronome subdivisions per beat.
  @JsonKey(defaultValue: 1)
  final int baseRegularBeats;

  /// Canonical/default beat modes.
  @JsonKey(
    defaultValue: [],
    fromJson: _beatModesFromJson,
    toJson: _beatModesToJson,
  )
  final List<List<BeatMode>> baseBeatModes;

  /// Canonical/default links.
  @JsonKey(defaultValue: [], fromJson: _linksFromJson, toJson: _linksToJson)
  final List<Link> baseLinks;

  /// When this record was created
  @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)
  final DateTime createdAt;

  /// When this record was last updated
  @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => _$CanonicalSongToJson(this);

  CanonicalSong copyWith({
    String? id,
    String? title,
    String? artist,
    List<String>? artists,
    String? album,
    int? releaseYear,
    int? durationMs,
    String? isrc,
    String? spotifyId,
    String? musicBrainzId,
    String? musicBrainzWorkId,
    String? iswc,
    String? normalizedTitle,
    String? normalizedArtist,
    List<String>? genres,
    String? disambiguation,
    int? schemaVersion,
    int? canonicalRevision,
    String? source,
    String? status,
    String? createdBy,
    String? baseKey,
    int? baseBpm,
    List<Section>? baseSections,
    int? baseAccentBeats,
    int? baseRegularBeats,
    List<List<BeatMode>>? baseBeatModes,
    List<Link>? baseLinks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CanonicalSong(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      artists: artists ?? this.artists,
      album: album ?? this.album,
      releaseYear: releaseYear ?? this.releaseYear,
      durationMs: durationMs ?? this.durationMs,
      isrc: isrc ?? this.isrc,
      spotifyId: spotifyId ?? this.spotifyId,
      musicBrainzId: musicBrainzId ?? this.musicBrainzId,
      musicBrainzWorkId: musicBrainzWorkId ?? this.musicBrainzWorkId,
      iswc: iswc ?? this.iswc,
      normalizedTitle: normalizedTitle ?? this.normalizedTitle,
      normalizedArtist: normalizedArtist ?? this.normalizedArtist,
      genres: genres ?? this.genres,
      disambiguation: disambiguation ?? this.disambiguation,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      canonicalRevision: canonicalRevision ?? this.canonicalRevision,
      source: source ?? this.source,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      baseKey: baseKey ?? this.baseKey,
      baseBpm: baseBpm ?? this.baseBpm,
      baseSections: baseSections ?? this.baseSections,
      baseAccentBeats: baseAccentBeats ?? this.baseAccentBeats,
      baseRegularBeats: baseRegularBeats ?? this.baseRegularBeats,
      baseBeatModes: baseBeatModes ?? this.baseBeatModes,
      baseLinks: baseLinks ?? this.baseLinks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get formatted duration (e.g., "3:45")
  String get formattedDuration {
    if (durationMs == null) return '';
    final minutes = durationMs! ~/ 60000;
    final seconds = ((durationMs! % 60000) / 1000).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Check if this song has MusicBrainz data
  bool get hasMusicBrainzData =>
      musicBrainzId != null || musicBrainzWorkId != null;

  /// Check if this song has ISRC
  bool get hasISRC => isrc != null && isrc!.isNotEmpty;

  /// Get display title (includes disambiguation if present)
  String get displayTitle {
    if (disambiguation != null && disambiguation!.isNotEmpty) {
      return '$title ($disambiguation)';
    }
    return title;
  }

  @override
  List<Object?> get props => [
    id,
    title,
    artist,
    album,
    releaseYear,
    musicBrainzId,
    musicBrainzWorkId,
    isrc,
    schemaVersion,
    canonicalRevision,
    source,
    status,
    baseKey,
    baseBpm,
    baseSections,
    baseAccentBeats,
    baseRegularBeats,
    baseBeatModes,
    baseLinks,
  ];
}

List<Link> _linksFromJson(value) {
  if (value == null) return [];
  if (value is List<Link>) return value;
  if (value is! List) return [];
  return value
      .whereType<Map<dynamic, dynamic>>()
      .map((item) => Link.fromJson(Map<String, dynamic>.from(item)))
      .toList();
}

List<Map<String, dynamic>> _linksToJson(List<Link> links) {
  return links.map((link) => link.toJson()).toList();
}

List<Section> _sectionsFromJson(value) {
  if (value == null) return [];
  if (value is List<Section>) return value;
  if (value is! List) return [];
  return value
      .whereType<Map<dynamic, dynamic>>()
      .map((item) => Section.fromJson(Map<String, dynamic>.from(item)))
      .toList();
}

List<Map<String, dynamic>> _sectionsToJson(List<Section> sections) {
  return sections.map((section) => section.toJson()).toList();
}

List<List<BeatMode>> _beatModesFromJson(value) {
  if (value == null) return [];

  if (value is List) {
    return value.map((beatRow) {
      if (beatRow is! List) return <BeatMode>[];
      return beatRow.map((modeValue) {
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

    final result = <List<BeatMode>>[];
    var maxBeat = 0;
    var maxSubdivision = 0;

    value.forEach((key, _) {
      final parts = key.toString().split('-');
      if (parts.length != 2) return;
      final beat = int.tryParse(parts[0]) ?? 0;
      final subdivision = int.tryParse(parts[1]) ?? 0;
      if (beat > maxBeat) maxBeat = beat;
      if (subdivision > maxSubdivision) maxSubdivision = subdivision;
    });

    for (var beat = 0; beat <= maxBeat; beat++) {
      result.add(List.filled(maxSubdivision + 1, BeatMode.normal));
    }

    value.forEach((key, modeValue) {
      final parts = key.toString().split('-');
      if (parts.length != 2) return;
      final beat = int.tryParse(parts[0]) ?? 0;
      final subdivision = int.tryParse(parts[1]) ?? 0;
      if (beat >= result.length || subdivision >= result[beat].length) return;
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

DateTime _parseDateTime(value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  try {
    if (value.runtimeType.toString() == 'Timestamp') {
      return (value as dynamic).toDate() as DateTime;
    }
  } catch (_) {}
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  return DateTime.now();
}

String _dateTimeToJson(DateTime value) => value.toIso8601String();
