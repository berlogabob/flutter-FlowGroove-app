import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'song_suggestion.g.dart';

/// Source of a song suggestion in autocomplete
enum SuggestionSource {
  /// User's personal library
  personal,

  /// Band/group library
  group,

  /// MusicBrainz API
  musicbrainz,

  /// Spotify API (search + audio-features for BPM/key)
  spotify,

  /// Local canonical collection
  canonical,
}

/// Type of match for suggestion
enum SuggestionType {
  /// Exact match (title + artist)
  exact,

  /// Similar title/artist (fuzzy match)
  similar,

  /// Same song, different version/arrangement
  variant,
}

/// Represents a song suggestion in autocomplete results
///
/// This is a unified model that combines results from:
/// - User's personal song library
/// - Band/group song libraries
/// - MusicBrainz API
/// - Local canonical song database
///
/// Each suggestion includes metadata about the source and match quality
/// to help users make informed decisions.
@JsonSerializable()
class SongSuggestion extends Equatable {
  const SongSuggestion({
    required this.id,
    required this.title,
    required this.artist,
    required this.source,
    required this.type,
    this.matchScore = 1.0,
    this.bandId,
    this.bandName,
    this.canonicalSongId,
    this.variantInfo,
    this.bpm,
    this.key,
    this.isForkable = false,
    this.album,
    this.releaseYear,
    this.durationMs,
    this.musicBrainzId,
    this.spotifyId,
    this.matchReasons = const [],
  });

  /// Create a suggestion from user's personal song.
  factory SongSuggestion.fromPersonalSong({
    required String id,
    required String title,
    required String artist,
    String? bpm,
    String? key,
    String? canonicalSongId,
    String? musicBrainzId,
  }) {
    return SongSuggestion(
      id: id,
      title: title,
      artist: artist,
      source: SuggestionSource.personal,
      type: SuggestionType.exact,
      bpm: bpm != null ? int.tryParse(bpm) : null,
      key: key,
      canonicalSongId: canonicalSongId,
      musicBrainzId: musicBrainzId,
      matchReasons: const ['In your library'],
    );
  }

  /// Create a suggestion from band/group song.
  factory SongSuggestion.fromGroupSong({
    required String id,
    required String title,
    required String artist,
    required String bandId,
    required String bandName,
    String? bpm,
    String? key,
    String? canonicalSongId,
    String? musicBrainzId,
    bool isForkable = true,
  }) {
    return SongSuggestion(
      id: id,
      title: title,
      artist: artist,
      source: SuggestionSource.group,
      type: SuggestionType.exact,
      bandId: bandId,
      bandName: bandName,
      bpm: bpm != null ? int.tryParse(bpm) : null,
      key: key,
      canonicalSongId: canonicalSongId,
      musicBrainzId: musicBrainzId,
      isForkable: isForkable,
      matchReasons: ['In $bandName'],
    );
  }

  /// Create a suggestion from MusicBrainz.
  factory SongSuggestion.fromMusicBrainz({
    required String id,
    required String title,
    required String artist,
    String? musicBrainzId,
    int? durationMs,
    int? releaseYear,
    String? album,
  }) {
    return SongSuggestion(
      id: 'mb_$id',
      title: title,
      artist: artist,
      source: SuggestionSource.musicbrainz,
      type: SuggestionType.exact,
      matchScore: 0.85, // API results are relevant but not exact match
      musicBrainzId: musicBrainzId,
      durationMs: durationMs,
      releaseYear: releaseYear,
      album: album,
      matchReasons: const ['From MusicBrainz'],
    );
  }

  /// Create a suggestion from local canonical database.
  factory SongSuggestion.fromCanonical({
    required String id,
    required String title,
    required String artist,
    String? canonicalSongId,
    int? bpm,
    String? key,
    int? durationMs,
    String? musicBrainzId,
    int? releaseYear,
    String? album,
    double matchScore = 0.9,
  }) {
    return SongSuggestion(
      id: id,
      title: title,
      artist: artist,
      source: SuggestionSource.canonical,
      type: matchScore >= 0.95 ? SuggestionType.exact : SuggestionType.similar,
      matchScore: matchScore,
      canonicalSongId: canonicalSongId ?? id,
      bpm: bpm,
      key: key,
      durationMs: durationMs,
      musicBrainzId: musicBrainzId,
      releaseYear: releaseYear,
      album: album,
      matchReasons: matchScore >= 0.95
          ? ['Exact match in database']
          : ['Similar song in database'],
    );
  }

  /// Create a suggestion from a Spotify track. BPM/key are filled later, on
  /// selection, via the audio-features endpoint (avoids an N+1 fetch at search).
  factory SongSuggestion.fromSpotify({
    required String id,
    required String title,
    required String artist,
    required String spotifyId,
    String? album,
    int? durationMs,
    double matchScore = 0.9,
  }) {
    return SongSuggestion(
      id: 'spotify_$id',
      title: title,
      artist: artist,
      source: SuggestionSource.spotify,
      type: matchScore >= 0.95 ? SuggestionType.exact : SuggestionType.similar,
      matchScore: matchScore,
      spotifyId: spotifyId,
      album: album,
      durationMs: durationMs,
      matchReasons: const ['From Spotify'],
    );
  }

  factory SongSuggestion.fromJson(Map<String, dynamic> json) =>
      _$SongSuggestionFromJson(json);

  /// Unique identifier for this suggestion
  final String id;

  /// Song title
  final String title;

  /// Artist name
  final String artist;

  /// Where this suggestion came from
  final SuggestionSource source;

  /// Type of match
  final SuggestionType type;

  /// Match score (0.0-1.0, where 1.0 is exact match)
  @JsonKey(defaultValue: 1.0)
  final double matchScore;

  /// Band ID (if source is group)
  final String? bandId;

  /// Band name (if source is group)
  final String? bandName;

  /// Link to canonical song ID
  final String? canonicalSongId;

  /// Variant info (e.g., "live", "acoustic", "remaster")
  final String? variantInfo;

  /// Tempo in BPM (if known)
  final int? bpm;

  /// Musical key (e.g., "C", "Gm", "A#")
  final String? key;

  /// Whether this group song can be forked to personal
  @JsonKey(defaultValue: false)
  final bool isForkable;

  /// Album name (if available)
  final String? album;

  /// Release year (if available)
  final int? releaseYear;

  /// Duration in milliseconds (if available)
  final int? durationMs;

  /// MusicBrainz ID (if from MusicBrainz)
  final String? musicBrainzId;

  /// Spotify track ID (if from Spotify) — used to fetch BPM/key on selection
  final String? spotifyId;

  /// Reasons why this song matched (for debugging/UI)
  @JsonKey(defaultValue: [])
  final List<String> matchReasons;

  Map<String, dynamic> toJson() => _$SongSuggestionToJson(this);

  SongSuggestion copyWith({
    String? id,
    String? title,
    String? artist,
    SuggestionSource? source,
    SuggestionType? type,
    double? matchScore,
    String? bandId,
    String? bandName,
    String? canonicalSongId,
    String? variantInfo,
    int? bpm,
    String? key,
    bool? isForkable,
    String? album,
    int? releaseYear,
    int? durationMs,
    String? musicBrainzId,
    String? spotifyId,
    List<String>? matchReasons,
  }) {
    return SongSuggestion(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      source: source ?? this.source,
      type: type ?? this.type,
      matchScore: matchScore ?? this.matchScore,
      bandId: bandId ?? this.bandId,
      bandName: bandName ?? this.bandName,
      canonicalSongId: canonicalSongId ?? this.canonicalSongId,
      variantInfo: variantInfo ?? this.variantInfo,
      bpm: bpm ?? this.bpm,
      key: key ?? this.key,
      isForkable: isForkable ?? this.isForkable,
      album: album ?? this.album,
      releaseYear: releaseYear ?? this.releaseYear,
      durationMs: durationMs ?? this.durationMs,
      musicBrainzId: musicBrainzId ?? this.musicBrainzId,
      spotifyId: spotifyId ?? this.spotifyId,
      matchReasons: matchReasons ?? this.matchReasons,
    );
  }

  /// Get formatted duration (e.g., "3:45")
  String? get formattedDuration {
    if (durationMs == null) return null;
    final minutes = durationMs! ~/ 60000;
    final seconds = ((durationMs! % 60000) / 1000).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get display subtitle with source info
  String get displaySubtitle {
    final parts = <String>[];

    if (bandName != null) {
      parts.add(bandName!);
    }

    if (album != null) {
      parts.add(album!);
    }

    if (releaseYear != null) {
      parts.add(releaseYear.toString());
    }

    if (variantInfo != null) {
      parts.add(variantInfo!);
    }

    return parts.join(' • ');
  }

  /// Get icon data for source
  String get sourceIconName {
    switch (source) {
      case SuggestionSource.personal:
        return 'person';
      case SuggestionSource.group:
        return 'group';
      case SuggestionSource.musicbrainz:
        return 'cloud';
      case SuggestionSource.spotify:
        return 'music_note';
      case SuggestionSource.canonical:
        return 'library_music';
    }
  }

  /// Get color name for source (use with MonoPulseColors)
  String get sourceColorName {
    switch (source) {
      case SuggestionSource.personal:
        return 'accentOrange';
      case SuggestionSource.group:
        return 'blue';
      case SuggestionSource.musicbrainz:
        return 'green';
      case SuggestionSource.spotify:
        return 'successGreen';
      case SuggestionSource.canonical:
        return 'purple';
    }
  }

  /// Check if this is a high-confidence match
  bool get isHighConfidence => matchScore >= 0.9;

  /// Check if this is a low-confidence match (needs review)
  bool get isLowConfidence => matchScore < 0.7;

  @override
  List<Object?> get props => [
    id,
    title,
    artist,
    source,
    canonicalSongId,
    bandId,
    musicBrainzId,
    spotifyId,
  ];
}
