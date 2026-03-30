import '../models/song.dart';
import '../models/song_suggestion.dart';
import '../models/canonical_song.dart';
import '../repositories/firestore_song_repository.dart';
import 'musicbrainz_service.dart';
import 'matching/fuzzy_matcher.dart';

/// Song Suggestion Service
/// 
/// Orchestrates song suggestions from multiple sources:
/// 1. User's personal library
/// 2. Band/group libraries
/// 3. MusicBrainz API
/// 4. Local canonical database
/// 
/// Usage:
/// ```dart
/// final service = SongSuggestionService(
///   songRepo: SongRepository(),
///   musicBrainz: MusicBrainzService(),
///   userId: currentUser.uid,
/// );
/// 
/// final suggestions = await service.getSuggestions(
///   query: 'Bohemian Rhapsody',
///   limit: 10,
/// );
/// ```
class SongSuggestionService {
  final FirestoreSongRepository _songRepo;
  final MusicBrainzService _musicBrainz;
  final String _userId;
  final String? _bandId;

  SongSuggestionService({
    required FirestoreSongRepository songRepo,
    required MusicBrainzService musicBrainz,
    required String userId,
    String? bandId,
  })  : _songRepo = songRepo,
        _musicBrainz = musicBrainz,
        _userId = userId,
        _bandId = bandId;

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

    // Search all sources in parallel
    final results = await Future.wait([
      _searchPersonal(title, artist),
      if (_bandId != null) _searchGroup(title, artist, _bandId!),
      _searchMusicBrainz(title, artist),
    ]);

    // Merge all results
    final allSuggestions = <SongSuggestion>[];
    for (final result in results) {
      allSuggestions.addAll(result);
    }

    // Deduplicate and sort
    final deduplicated = _deduplicateSuggestions(allSuggestions);
    deduplicated.sort((a, b) => b.matchScore.compareTo(a.matchScore));

    // Limit results
    return deduplicated.take(limit).toList();
  }

  /// Search user's personal song library
  Future<List<SongSuggestion>> _searchPersonal(
    String title,
    String artist,
  ) async {
    try {
      // Get user's songs from repository
      final songs = await _songRepo.getSongs(_userId);
      
      final suggestions = <SongSuggestion>[];
      
      for (final song in songs) {
        final matchResult = FuzzyMatcher.calculateMatchScore(
          inputTitle: title,
          inputArtist: artist,
          targetTitle: song.title,
          targetArtist: song.artist,
          targetAlbum: song.album,
        );
        
        // Only include good matches
        if (matchResult.overall >= 0.6) {
          suggestions.add(SongSuggestion(
            id: song.id,
            title: song.title,
            artist: song.artist,
            source: SuggestionSource.personal,
            type: matchResult.isExactMatch
                ? SuggestionType.exact
                : SuggestionType.similar,
            matchScore: matchResult.overall,
            bpm: song.originalBPM ?? song.ourBPM,
            key: song.originalKey ?? song.ourKey,
            canonicalSongId: song.canonicalSongId,
            isForkable: false,
            matchReasons: _buildMatchReasons(matchResult),
          ));
        }
      }
      
      return suggestions;
    } catch (e) {
      // Return empty list on error (don't break UX)
      return [];
    }
  }

  /// Search band/group song library
  Future<List<SongSuggestion>> _searchGroup(
    String title,
    String artist,
    String bandId,
  ) async {
    try {
      // Get band's songs from repository
      final songs = await _songRepo.getBandSongs(bandId);
      
      final suggestions = <SongSuggestion>[];
      
      for (final song in songs) {
        final matchResult = FuzzyMatcher.calculateMatchScore(
          inputTitle: title,
          inputArtist: artist,
          targetTitle: song.title,
          targetArtist: song.artist,
          targetAlbum: song.album,
        );
        
        if (matchResult.overall >= 0.6) {
          suggestions.add(SongSuggestion.fromGroupSong(
            id: song.id,
            title: song.title,
            artist: song.artist,
            bandId: bandId,
            bandName: 'Band', // TODO: Get actual band name
            bpm: (song.originalBPM ?? song.ourBPM)?.toString(),
            key: song.originalKey ?? song.ourKey,
            canonicalSongId: song.canonicalSongId,
            isForkable: true, // Group songs can be forked to personal
          ));
        }
      }
      
      return suggestions;
    } catch (e) {
      return [];
    }
  }

  /// Search MusicBrainz API
  Future<List<SongSuggestion>> _searchMusicBrainz(
    String title,
    String artist,
  ) async {
    try {
      // Search MusicBrainz
      final recordings = await _musicBrainz.searchRecording(
        title: title,
        artist: artist,
        limit: 5,
      );
      
      return recordings
          .map((rec) => SongSuggestion.fromMusicBrainz(
                id: rec.id,
                title: rec.title,
                artist: rec.artist,
                musicBrainzId: rec.id,
                durationMs: rec.lengthMs,
                releaseYear: rec.releaseYear,
                album: rec.album,
              ))
          .toList();
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
      // Create unique key from normalized title + artist
      final key = '${suggestion.title.toLowerCase().trim()}|'
          '${suggestion.artist.toLowerCase().trim()}';
      
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

  /// Get source priority (lower = better)
  int _sourcePriority(SongSuggestion s) {
    switch (s.source) {
      case SuggestionSource.personal:
        return 1;
      case SuggestionSource.group:
        return 2;
      case SuggestionSource.canonical:
        return 3;
      case SuggestionSource.musicbrainz:
        return 4;
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

  /// Build match reasons list
  List<String> _buildMatchReasons(MatchResult match) {
    final reasons = <String>[];
    
    if (match.title >= 0.95) {
      reasons.add('Exact title match');
    } else if (match.title >= 0.85) {
      reasons.add('Close title match');
    }
    
    if (match.artist >= 0.95) {
      reasons.add('Exact artist match');
    } else if (match.artist >= 0.85) {
      reasons.add('Close artist match');
    }
    
    if (match.album > 0) {
      reasons.add('Album match');
    }
    
    return reasons;
  }
}

/// Parsed query parts
class _QueryParts {
  final String title;
  final String artist;

  _QueryParts({required this.title, required this.artist});
}
