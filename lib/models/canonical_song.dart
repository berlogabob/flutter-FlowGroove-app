import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

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

  /// When this record was created
  final DateTime createdAt;

  /// When this record was last updated
  final DateTime updatedAt;

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
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

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

  factory CanonicalSong.fromJson(Map<String, dynamic> json) =>
      _$CanonicalSongFromJson(json);

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
  bool get hasMusicBrainzData => musicBrainzId != null || musicBrainzWorkId != null;

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
      ];
}
