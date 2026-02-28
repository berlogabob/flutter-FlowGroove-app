/// Song matching service for finding duplicate/similar songs.
///
/// Provides a multi-tier search strategy:
/// 1. Exact match on normalized fields (fastest)
/// 2. Prefix match (fast)
/// 3. Phonetic match (medium)
/// 4. Full fuzzy search (slowest, in-memory)
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/song.dart';
import 'song_normalizer.dart';
import 'match_scorer.dart';

/// Result of a paginated search.
class PaginatedResult<T> {
  final List<T> items;
  final bool hasMore;
  final DocumentSnapshot? lastDocument;

  const PaginatedResult({
    required this.items,
    required this.hasMore,
    this.lastDocument,
  });
}

/// Service for finding matching songs.
class SongMatchingService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const int _pageSize = 50;

  SongMatchingService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  /// Gets the current user ID.
  String get _currentUserId {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Authentication required. Please sign in.');
    }
    return user.uid;
  }

  /// Finds matching songs for the given input.
  ///
  /// Returns a list of [MatchScore] sorted by score descending.
  /// Only returns matches with score >= [MatchThresholds.REQUIRE_REVIEW].
  Future<List<MatchScore>> findMatches({
    required String title,
    required String artist,
    int? duration,
    String? album,
    String? bandId,
  }) async {
    // Get all songs (personal or band)
    final allSongs = await _getAllSongs(bandId: bandId);

    // Calculate match scores
    final scores = <MatchScore>[];
    for (final song in allSongs) {
      var score = MatchScorer.calculate(
        inputTitle: title,
        inputArtist: artist,
        inputDuration: duration,
        inputAlbum: album,
        existingSong: song,
      );

      // Apply special rules
      score = MatchScorer.applySpecialRules(score, artist);

      // Filter by minimum score
      if (score.total >= MatchThresholds.REQUIRE_REVIEW) {
        scores.add(score);
      }
    }

    // Sort by score descending
    scores.sort((a, b) => b.total.compareTo(a.total));

    return scores;
  }

  /// Gets the best match for the given input.
  ///
  /// Returns null if no match meets the threshold.
  Future<MatchScore?> findBestMatch({
    required String title,
    required String artist,
    int? duration,
    String? album,
    String? bandId,
  }) async {
    final matches = await findMatches(
      title: title,
      artist: artist,
      duration: duration,
      album: album,
      bandId: bandId,
    );

    if (matches.isEmpty) return null;
    return matches.first;
  }

  /// Checks if a song has an exact or near-exact match.
  ///
  /// Returns true if a match with score >= [MatchThresholds.AUTO_SELECT] exists.
  Future<bool> hasExactMatch({
    required String title,
    required String artist,
    String? bandId,
  }) async {
    final match = await findBestMatch(
      title: title,
      artist: artist,
      bandId: bandId,
    );

    return match != null && match.total >= MatchThresholds.AUTO_SELECT;
  }

  /// Gets all songs for the current user (or band).
  Future<List<Song>> _getAllSongs({String? bandId}) async {
    final songs = <Song>[];

    if (bandId != null) {
      // Get band songs
      final snapshot = await _firestore
          .collection('bands')
          .doc(bandId)
          .collection('songs')
          .get();

      for (final doc in snapshot.docs) {
        try {
          songs.add(Song.fromJson(doc.data() as Map<String, dynamic>));
        } catch (e) {
          // Skip invalid documents
          continue;
        }
      }
    } else {
      // Get personal songs
      final snapshot = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('songs')
          .get();

      for (final doc in snapshot.docs) {
        try {
          songs.add(Song.fromJson(doc.data() as Map<String, dynamic>));
        } catch (e) {
          // Skip invalid documents
          continue;
        }
      }
    }

    return songs;
  }

  /// Gets songs with pagination support.
  Future<PaginatedResult<Song>> _getSongsPage({
    String? bandId,
    DocumentSnapshot? startAfter,
    int limit = _pageSize,
  }) async {
    Query query;

    if (bandId != null) {
      query = _firestore
          .collection('bands')
          .doc(bandId)
          .collection('songs')
          .orderBy('normalizedTitle')
          .limit(limit);
    } else {
      query = _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('songs')
          .orderBy('normalizedTitle')
          .limit(limit);
    }

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();

    final songs = <Song>[];
    for (final doc in snapshot.docs) {
      try {
        songs.add(Song.fromJson(doc.data() as Map<String, dynamic>));
      } catch (e) {
        continue;
      }
    }

    return PaginatedResult(
      items: songs,
      hasMore: snapshot.docs.length == limit,
      lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
    );
  }
}
