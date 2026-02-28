/// Match scoring system for song comparison.
///
/// Calculates a weighted multi-factor match score based on:
/// - Title similarity (40%)
/// - Artist similarity (40%)
/// - Duration similarity (10%)
/// - Album similarity (10%)
library;

import 'dart:math' show min, max;

import '../../models/song.dart';
import 'song_normalizer.dart';
import 'fuzzy_matcher.dart';

/// Match confidence thresholds.
class MatchThresholds {
  /// Minimum score to show in search results.
  static const double REQUIRE_REVIEW = 70.0;

  /// Score at which to show "Did you mean?" suggestion.
  static const double SUGGEST_MATCH = 85.0;

  /// Score at which to auto-suggest with high confidence.
  static const double AUTO_SELECT = 98.0;

  /// Score considered an exact match.
  static const double EXACT_MATCH = 99.5;

  /// Minimum title similarity required.
  static const double MIN_TITLE_SIMILARITY = 60.0;

  /// Minimum artist similarity required.
  static const double MIN_ARTIST_SIMILARITY = 50.0;

  /// Bonus for phonetic match.
  static const double PHONETIC_BOOST = 5.0;
}

/// Match score grade.
enum MatchGrade {
  /// 95-100%: Exact match
  exact,

  /// 85-94%: High confidence
  high,

  /// 70-84%: Medium confidence
  medium,

  /// 50-69%: Low confidence
  low,

  /// <50%: No match
  none,
}

/// Represents a match score between input and existing song.
class MatchScore {
  /// Total match score (0-100).
  final double total;

  /// Title similarity component (0-100).
  final double titleSimilarity;

  /// Artist similarity component (0-100).
  final double artistSimilarity;

  /// Duration similarity component (0-100).
  final double durationSimilarity;

  /// Album similarity component (0-100).
  final double albumSimilarity;

  /// The matched song.
  final Song matchedSong;

  /// Match grade based on score.
  MatchGrade get grade {
    if (total >= 95) return MatchGrade.exact;
    if (total >= 85) return MatchGrade.high;
    if (total >= 70) return MatchGrade.medium;
    if (total >= 50) return MatchGrade.low;
    return MatchGrade.none;
  }

  /// Whether this is a strong match (>= 85%).
  bool get isStrongMatch => total >= MatchThresholds.SUGGEST_MATCH;

  /// Whether this should be shown as a suggestion (>= 70%).
  bool get shouldSuggest => total >= MatchThresholds.REQUIRE_REVIEW;

  const MatchScore({
    required this.total,
    required this.titleSimilarity,
    required this.artistSimilarity,
    required this.durationSimilarity,
    required this.albumSimilarity,
    required this.matchedSong,
  });

  @override
  String toString() {
    return 'MatchScore(total: ${total.toStringAsFixed(1)}%, '
        'grade: ${grade.name}, '
        'song: "${matchedSong.title}" by "${matchedSong.artist}")';
  }
}

/// Calculates match scores between input and existing songs.
class MatchScorer {
  /// Calculates a comprehensive match score.
  ///
  /// [inputTitle] - The title entered by the user
  /// [inputArtist] - The artist entered by the user
  /// [inputDuration] - Optional duration in milliseconds
  /// [inputAlbum] - Optional album name
  /// [existingSong] - The existing song to compare against
  static MatchScore calculate({
    required String inputTitle,
    required String inputArtist,
    int? inputDuration,
    String? inputAlbum,
    required Song existingSong,
  }) {
    // Normalize inputs
    final normInputTitle = SongNormalizer.normalizeTitle(inputTitle);
    final normInputArtist = SongNormalizer.normalizeArtist(inputArtist);
    final normExistingTitle = SongNormalizer.normalizeTitle(existingSong.title);
    final normExistingArtist = SongNormalizer.normalizeArtist(
      existingSong.artist,
    );

    // Calculate title similarity (weighted average of algorithms)
    final titleLevenshtein = Levenshtein.similarity(
      normInputTitle,
      normExistingTitle,
    );
    final titleJaroWinkler = JaroWinkler.similarity(
      normInputTitle,
      normExistingTitle,
    );
    final titleTokenSort = TokenSortRatio.similarity(
      normInputTitle,
      normExistingTitle,
    );
    final titleSoundex = Soundex.similarity(normInputTitle, normExistingTitle);

    final titleSimilarity =
        (titleLevenshtein * 0.35 +
            titleJaroWinkler * 0.35 +
            titleTokenSort * 0.20 +
            titleSoundex * 0.10) *
        100;

    // Calculate artist similarity
    final artistLevenshtein = Levenshtein.similarity(
      normInputArtist,
      normExistingArtist,
    );
    final artistJaroWinkler = JaroWinkler.similarity(
      normInputArtist,
      normExistingArtist,
    );
    final artistTokenSort = TokenSortRatio.similarity(
      normInputArtist,
      normExistingArtist,
    );

    final artistSimilarity =
        (artistLevenshtein * 0.40 +
            artistJaroWinkler * 0.40 +
            artistTokenSort * 0.20) *
        100;

    // Calculate duration similarity (if available)
    double durationSimilarity = 0.0;
    bool hasDuration = false;
    if (inputDuration != null && existingSong.durationMs != null) {
      final durationDiff = (inputDuration - existingSong.durationMs!).abs();
      // Within 5 seconds = 100%, within 10 seconds = 80%, etc.
      durationSimilarity = max(0, 1.0 - (durationDiff / 10000)) * 100;
      hasDuration = true;
    }

    // Calculate album similarity (if available)
    double albumSimilarity = 0.0;
    bool hasAlbum = false;
    if (inputAlbum != null && inputAlbum.isNotEmpty) {
      final normInputAlbum = SongNormalizer.normalizeTitle(inputAlbum);
      final normExistingAlbum = SongNormalizer.normalizeTitle(
        existingSong.album ?? '',
      );
      if (normExistingAlbum.isNotEmpty) {
        albumSimilarity =
            Levenshtein.similarity(normInputAlbum, normExistingAlbum) * 100;
        hasAlbum = true;
      }
    }

    // Calculate final weighted score
    // Redistribute weights if duration/album are not available
    double titleWeight = 0.40;
    double artistWeight = 0.40;
    double durationWeight = hasDuration ? 0.10 : 0.0;
    double albumWeight = hasAlbum ? 0.10 : 0.0;

    // Redistribute missing weights to title and artist
    final missingWeight = (0.10 - durationWeight) + (0.10 - albumWeight);
    titleWeight += missingWeight / 2;
    artistWeight += missingWeight / 2;

    final score =
        (titleSimilarity * titleWeight +
        artistSimilarity * artistWeight +
        durationSimilarity * durationWeight +
        albumSimilarity * albumWeight);

    return MatchScore(
      total: score,
      titleSimilarity: titleSimilarity,
      artistSimilarity: artistSimilarity,
      durationSimilarity: durationSimilarity,
      albumSimilarity: albumSimilarity,
      matchedSong: existingSong,
    );
  }

  /// Applies special rules and edge case adjustments to a score.
  static MatchScore applySpecialRules(MatchScore score, String inputArtist) {
    double adjustedScore = score.total;

    // Case 1: Empty artist input - weight title higher
    if (inputArtist.trim().isEmpty) {
      adjustedScore =
          (score.titleSimilarity * 0.70 +
          score.durationSimilarity * 0.15 +
          score.albumSimilarity * 0.15);
    }

    // Case 2: Live version detection
    if (_isLiveVersion(score.matchedSong)) {
      final inputNorm = SongNormalizer.normalizeTitle(inputArtist);
      if (!inputNorm.contains('live')) {
        // User didn't search for live version - reduce score
        adjustedScore *= 0.85;
      }
    }

    // Case 3: Phonetic match bonus
    if (Soundex.isSimilar(
      SongNormalizer.normalizeTitle(inputArtist),
      SongNormalizer.normalizeTitle(score.matchedSong.title),
    )) {
      adjustedScore = min(100, adjustedScore + MatchThresholds.PHONETIC_BOOST);
    }

    return MatchScore(
      total: adjustedScore,
      titleSimilarity: score.titleSimilarity,
      artistSimilarity: score.artistSimilarity,
      durationSimilarity: score.durationSimilarity,
      albumSimilarity: score.albumSimilarity,
      matchedSong: score.matchedSong,
    );
  }

  static bool _isLiveVersion(Song song) {
    // Check original title (before normalization) for live indicators
    final originalTitle = song.title.toLowerCase();
    return originalTitle.contains('(live)') ||
        originalTitle.contains(' live ') ||
        originalTitle.endsWith(' live') ||
        song.tags.contains('live') ||
        song.variantType == 'live';
  }
}
