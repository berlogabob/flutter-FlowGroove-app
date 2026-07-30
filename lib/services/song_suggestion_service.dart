import '../models/song_suggestion.dart';
import '../repositories/canonical_song_repository.dart';
import 'matching/fuzzy_matcher.dart';
import 'musicbrainz_service.dart';

/// Song Suggestion Service
///
/// Orchestrates song autofill suggestions from EXTERNAL sources only:
/// 1. Canonical song catalog (Firestore)
/// 2. MusicBrainz API
///
/// Spotify and Deezer used to be searched here too. Spotify needs a client
/// secret (which must never ship in the app bundle) and Deezer needs a CORS
/// proxy for web, so both moved into the server-side resolver
/// (functions/src/metadata/resolver.js), reached via the lookupTrackMetadata
/// callable once the user picks a match.
///
/// The user's own/band library is deliberately NOT searched here — autofill
/// is for pulling in new song metadata, and library hits crowded out the web
/// results (#78). Save-time duplicate detection covers the "already have it"
/// case separately.
///
/// Usage:
/// ```dart
/// final service = SongSuggestionService(
///   musicBrainz: MusicBrainzService(),
/// );
///
/// final suggestions = await service.getSuggestions(
///   query: 'Bohemian Rhapsody',
///   limit: 10,
/// );
/// ```
class SongSuggestionService {

  SongSuggestionService({
    required this._musicBrainz,
    this._canonicalRepo,
  });
  final CanonicalSongRepository? _canonicalRepo;
  final MusicBrainzService _musicBrainz;

  /// Get suggestions as user types
  ///
  /// Searches all sources in parallel and merges results.
  /// Results are sorted by match score (highest first).
  ///
  /// [query] - User's search query (minimum 2 characters)
  /// [limit] - Maximum number of suggestions to return
  ///
  /// Returns list of [SongSuggestion] from all sources.
  Future<List<SongSuggestion>> getSuggestions({
    required String query,
    int limit = 10,
  }) async {
    if (query.length < 2) return [];

    // Parse query into title and artist
    final parts = _parseQuery(query);
    final title = parts.title;
    final artist = parts.artist;

    // Search in parallel. Only keyless, browser-reachable sources run here:
    // the canonical catalog (Firestore) and MusicBrainz. Spotify needs a client
    // secret and Deezer needs a CORS proxy, so both moved server-side into
    // functions/src/metadata/resolver.js — reached through the
    // lookupTrackMetadata callable once a match is chosen. This also matches how
    // the feature is documented: matches come from MusicBrainz, tempo from
    // Deezer at enrichment time.
    final results = await Future.wait([
      if (_canonicalRepo != null) _searchCanonical(title, artist),
      _searchMusicBrainz(title, artist),
    ]);

    // Merge all results
    final allSuggestions = <SongSuggestion>[];
    for (final result in results) {
      allSuggestions.addAll(result);
    }

    // Deduplicate and sort
    var deduplicated = _deduplicateSuggestions(allSuggestions);

    // ponytail: bare query has no artist field — when a suggestion's artist
    // is literally in what the user typed ("ride the lightning METALLICA"),
    // it's the original, not a cover; boost it above the same-title ties.
    // Naive substring; tighten to token matching if short names misfire.
    if (artist.isEmpty) {
      final q = query.toLowerCase();
      deduplicated = deduplicated.map((s) {
        final a = s.artist.toLowerCase().trim();
        return a.length >= 3 && q.contains(a)
            ? s.copyWith(
                matchScore: (s.matchScore + 0.1).clamp(0.0, 1.0),
              )
            : s;
      }).toList();
    }

    deduplicated.sort((a, b) => b.matchScore.compareTo(a.matchScore));

    // Limit results
    return deduplicated.take(limit).toList();
  }

  /// Search canonical song catalog
  Future<List<SongSuggestion>> _searchCanonical(
    String title,
    String artist,
  ) async {
    final canonicalRepo = _canonicalRepo;
    if (canonicalRepo == null) return [];

    try {
      final query = title.isNotEmpty ? title : artist;
      final canonicalSongs = await canonicalRepo.search(query: query, limit: 8);
      final suggestions = <SongSuggestion>[];

      for (final song in canonicalSongs) {
        final matchResult = FuzzyMatcher.calculateMatchScore(
          inputTitle: title,
          inputArtist: artist,
          targetTitle: song.title,
          targetArtist: song.artist,
          targetAlbum: song.album,
        );

        if (matchResult.overall >= 0.6) {
          suggestions.add(
            SongSuggestion.fromCanonical(
              id: song.id,
              title: song.title,
              artist: song.artist,
              canonicalSongId: song.id,
              album: song.album,
              bpm: song.baseBpm,
              key: song.baseKey,
              durationMs: song.durationMs,
              musicBrainzId: song.musicBrainzId,
              matchScore: matchResult.overall,
            ),
          );
        }
      }

      return suggestions;
    } catch (e) {
      return [];
    }
  }

  /// Search MusicBrainz — the primary external source for matches. Keyless and
  /// CORS-reachable, so it runs client-side on every platform including web.
  /// Results are fuzzy-scored + filtered against the query.
  Future<List<SongSuggestion>> _searchMusicBrainz(
    String title,
    String artist,
  ) async {
    try {
      // Search MusicBrainz
      final recordings = await _musicBrainz.searchRecording(
        title: title,
        artist: artist,
        limit: 8,
      );

      // Score and filter each recording against the query, exactly like the
      // other sources — MusicBrainz returns many loose / same-title / foreign
      // (e.g. Cyrillic) matches that must not be promoted to the top with a
      // flat score. (#75)
      final suggestions = <SongSuggestion>[];
      for (final rec in recordings) {
        final match = FuzzyMatcher.calculateMatchScore(
          inputTitle: title,
          inputArtist: artist,
          targetTitle: rec.title,
          targetArtist: rec.artist,
          targetAlbum: rec.album,
        );
        if (match.overall < 0.6) continue;
        suggestions.add(
          SongSuggestion.fromMusicBrainz(
            id: rec.id,
            title: rec.title,
            artist: rec.artist,
            musicBrainzId: rec.id,
            durationMs: rec.lengthMs,
            releaseYear: rec.releaseYear,
            album: rec.album,
          ).copyWith(matchScore: match.overall),
        );
      }
      return suggestions;
    } catch (e) {
      // MusicBrainz errors are expected (rate limits, network, etc.)
      // Return empty list - not critical
      return [];
    }
  }

  /// Deduplicate suggestions across sources
  List<SongSuggestion> _deduplicateSuggestions(
    List<SongSuggestion> suggestions,
  ) {
    final seen = <String, SongSuggestion>{};

    for (final suggestion in suggestions) {
      final key = _dedupeKey(suggestion);

      final existing = seen[key];

      if (existing == null) {
        // First time seeing this song
        seen[key] = suggestion;
      } else {
        // Already seen - keep highest score or prefer personal/group
        if (suggestion.matchScore > existing.matchScore) {
          seen[key] = suggestion;
        } else if (suggestion.matchScore == existing.matchScore) {
          // Prefer personal over group over MusicBrainz
          if (_sourcePriority(suggestion) < _sourcePriority(existing)) {
            seen[key] = suggestion;
          }
        }
      }
    }

    return seen.values.toList();
  }

  String _dedupeKey(SongSuggestion suggestion) {
    final musicBrainzId = suggestion.musicBrainzId;
    if (musicBrainzId != null && musicBrainzId.isNotEmpty) {
      return 'musicbrainz:$musicBrainzId';
    }

    final canonicalSongId = suggestion.canonicalSongId;
    if (canonicalSongId != null && canonicalSongId.isNotEmpty) {
      return 'canonical:$canonicalSongId';
    }

    final spotifyId = suggestion.spotifyId;
    if (spotifyId != null && spotifyId.isNotEmpty) {
      return 'spotify:$spotifyId';
    }

    // Some sources carry no cross-source id, so key on title|artist below.

    return '${suggestion.title.toLowerCase().trim()}|'
        '${suggestion.artist.toLowerCase().trim()}';
  }

  /// Get source priority (lower = better)
  int _sourcePriority(SongSuggestion s) {
    switch (s.source) {
      case SuggestionSource.personal:
        return 1;
      case SuggestionSource.group:
        return 2;
      case SuggestionSource.spotify:
        return 3;
      case SuggestionSource.deezer:
        return 4;
      case SuggestionSource.canonical:
        return 5;
      case SuggestionSource.musicbrainz:
        return 6;
    }
  }

  /// Parse query into title and artist
  _QueryParts _parseQuery(String query) {
    final trimmed = query.trim();

    // Try to split on common separators
    final separators = [' - ', ' by ', ': ', ' • '];

    for (final sep in separators) {
      if (trimmed.contains(sep)) {
        final parts = trimmed.split(sep);
        if (parts.length >= 2) {
          return _QueryParts(
            title: parts.first.trim(),
            artist: parts.skip(1).join(sep).trim(),
          );
        }
      }
    }

    // No separator found - treat entire query as title
    return _QueryParts(title: trimmed, artist: '');
  }
}

/// Parsed query parts
class _QueryParts {

  _QueryParts({required this.title, required this.artist});
  final String title;
  final String artist;
}
