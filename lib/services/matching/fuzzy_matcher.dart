/// Fuzzy string matching algorithms for song comparison.
///
/// This library implements multiple string similarity algorithms:
/// - Levenshtein Distance (edit distance)
/// - Damerau-Levenshtein (with transpositions)
/// - Jaro-Winkler Distance (prefix-boosted)
/// - Token Sort Ratio (word order independent)
/// - Soundex (phonetic encoding)
library;

import 'dart:math' show max, min;

/// Levenshtein distance calculator.
///
/// Measures the minimum number of single-character edits
/// (insertions, deletions, substitutions) required to change
/// one string into another.
class Levenshtein {
  /// Calculates the Levenshtein distance between two strings.
  ///
  /// Returns the minimum number of single-character edits required
  /// to transform [s1] into [s2].
  static int distance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    // Use Damerau-Levenshtein (includes transpositions)
    final matrix = List.generate(
      s2.length + 1,
      (i) => List.filled(s1.length + 1, 0),
    );

    for (var i = 0; i <= s1.length; i++) {
      matrix[0][i] = i;
    }
    for (var j = 0; j <= s2.length; j++) {
      matrix[j][0] = j;
    }

    for (var j = 1; j <= s2.length; j++) {
      for (var i = 1; i <= s1.length; i++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[j][i] = [
          matrix[j][i - 1] + 1, // deletion
          matrix[j - 1][i] + 1, // insertion
          matrix[j - 1][i - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);

        // Damerau extension: transposition
        if (i > 1 &&
            j > 1 &&
            s1[i - 1] == s2[j - 2] &&
            s1[i - 2] == s2[j - 1]) {
          matrix[j][i] = min(matrix[j][i], matrix[j - 2][i - 2] + cost);
        }
      }
    }

    return matrix[s2.length][s1.length];
  }

  /// Calculates similarity as a ratio between 0.0 and 1.0.
  ///
  /// 1.0 means identical strings, 0.0 means completely different.
  static double similarity(String s1, String s2) {
    final maxLen = max(s1.length, s2.length);
    if (maxLen == 0) return 1;
    return 1.0 - (distance(s1, s2) / maxLen);
  }
}

/// Jaro-Winkler distance calculator.
///
/// Particularly effective for short strings with common prefixes,
/// such as song titles. Boosts similarity score for strings that
/// share a common prefix.
class JaroWinkler {
  static const double _prefixWeight = 0.1;
  static const int _maxPrefixLength = 4;

  /// Calculates Jaro-Winkler similarity between two strings.
  ///
  /// Returns a value between 0.0 (no similarity) and 1.0 (identical).
  /// Strings with common prefixes receive a bonus.
  static double similarity(String s1, String s2) {
    if (s1 == s2) return 1;
    if (s1.isEmpty || s2.isEmpty) return 0;

    final searchRange = (max(s1.length, s2.length) ~/ 2) - 1;
    if (searchRange < 0) return 0;

    final s1Matches = List.filled(s1.length, false);
    final s2Matches = List.filled(s2.length, false);

    int matches = 0;
    double transpositions = 0;

    // Find matches
    for (var i = 0; i < s1.length; i++) {
      final start = max(0, i - searchRange);
      final end = min(i + searchRange + 1, s2.length);

      for (var j = start; j < end; j++) {
        if (s2Matches[j] || s1[i] != s2[j]) continue;
        s1Matches[i] = true;
        s2Matches[j] = true;
        matches++;
        break;
      }
    }

    if (matches == 0) return 0;

    // Count transpositions
    var k = 0;
    for (var i = 0; i < s1.length; i++) {
      if (!s1Matches[i]) continue;
      while (!s2Matches[k]) {
        k++;
      }
      if (s1[i] != s2[k]) transpositions++;
      k++;
    }
    transpositions /= 2;

    // Calculate Jaro similarity
    final jaro =
        (matches / s1.length +
            matches / s2.length +
            (matches - transpositions) / matches) /
        3;

    // Calculate common prefix length
    int prefixLength = 0;
    for (var i = 0; i < min(_maxPrefixLength, min(s1.length, s2.length)); i++) {
      if (s1[i] == s2[i]) {
        prefixLength++;
      } else {
        break;
      }
    }

    // Apply Winkler modification (boost for common prefix)
    return jaro + (prefixLength * _prefixWeight * (1 - jaro));
  }
}

/// Token Sort Ratio calculator.
///
/// Handles word order variations by sorting tokens before comparison.
/// Useful for matching "Queen Bohemian Rhapsody" vs "Bohemian Rhapsody Queen".
class TokenSortRatio {
  /// Calculates similarity after sorting tokens alphabetically.
  ///
  /// Returns a value between 0.0 and 1.0.
  static double similarity(String s1, String s2) {
    // Split into tokens and sort
    final tokens1 = s1.split(RegExp(r'\s+'))..sort();
    final tokens2 = s2.split(RegExp(r'\s+'))..sort();

    // Join sorted tokens
    final sorted1 = tokens1.join(' ');
    final sorted2 = tokens2.join(' ');

    // Calculate Levenshtein similarity on sorted strings
    return Levenshtein.similarity(sorted1, sorted2);
  }
}

/// Soundex phonetic encoding algorithm.
///
/// Encodes words based on their pronunciation, allowing matching
/// of homophones and similar-sounding words.
class Soundex {
  /// Encodes a string into its Soundex representation.
  ///
  /// Returns a 4-character code: first letter followed by 3 digits.
  /// Similar-sounding words will have the same Soundex code.
  static String encode(String input) {
    if (input.isEmpty) return '';

    final upperInput = input.toUpperCase();
    final firstLetter = upperInput[0];

    // Soundex mapping:
    // B, F, P, V = 1
    // C, G, J, K, Q, S, X, Z = 2
    // D, T = 3
    // L = 4
    // M, N = 5
    // R = 6
    // A, E, I, O, U, H, W, Y = 0 (ignored)
    final encoding = StringBuffer(firstLetter);
    String? lastCode;

    for (var i = 1; i < input.length; i++) {
      final char = input[i];
      String? code;

      if ('BFPV'.contains(char)) {
        code = '1';
      } else if ('CGJKQSXZ'.contains(char))
        code = '2';
      else if ('DT'.contains(char))
        code = '3';
      else if ('L'.contains(char))
        code = '4';
      else if ('MN'.contains(char))
        code = '5';
      else if ('R'.contains(char))
        code = '6';

      if (code != null && code != lastCode) {
        encoding.write(code);
      }
      lastCode = code;
    }

    // Pad to 4 characters
    var result = encoding.toString();
    while (result.length < 4) {
      result += '0';
    }
    return result.substring(0, 4);
  }

  /// Checks if two strings sound similar based on Soundex.
  static bool isSimilar(String s1, String s2) {
    if (s1.isEmpty || s2.isEmpty) return false;
    return encode(s1) == encode(s2);
  }

  /// Calculates similarity based on Soundex match.
  ///
  /// Returns 1.0 if Soundex codes match, 0.0 otherwise.
  static double similarity(String s1, String s2) {
    return isSimilar(s1, s2) ? 1.0 : 0.0;
  }
}

/// Comprehensive multi-field fuzzy matcher for songs.
///
/// Combines multiple similarity algorithms with weighted scoring
/// across title, artist, and album fields.
class FuzzyMatcher {
  /// Calculate multi-field match score for songs.
  ///
  /// Weights:
  /// - Title: 50%
  /// - Artist: 30%
  /// - Album: 20% (if available)
  ///
  /// Uses combination of Levenshtein and Jaro-Winkler for best accuracy.
  static MatchResult calculateMatchScore({
    required String inputTitle,
    required String inputArtist,
    required String targetTitle,
    required String targetArtist,
    String? inputAlbum,
    String? targetAlbum,
  }) {
    // Normalize inputs
    final normInputTitle = _normalize(inputTitle);
    final normInputArtist = _normalize(inputArtist);
    final normInputAlbum = _normalize(inputAlbum ?? '');
    
    final normTargetTitle = _normalize(targetTitle);
    final normTargetArtist = _normalize(targetArtist);
    final normTargetAlbum = _normalize(targetAlbum ?? '');
    
    // Calculate individual scores using best algorithm for each
    final titleScore = _calculateTitleScore(normInputTitle, normTargetTitle);
    final artistScore = _calculateArtistScore(normInputArtist, normTargetArtist);
    final albumScore = targetAlbum != null && targetAlbum.isNotEmpty &&
            normTargetAlbum.isNotEmpty
        ? Levenshtein.similarity(normInputAlbum, normTargetAlbum)
        : 0.0;
    
    // Weighted average
    double overallScore;

    if (normInputArtist.isEmpty) {
      // Artist not typed yet (partial query) — scoring the empty artist
      // against targets would dilute real title matches below the display
      // threshold and inflate junk whose artist also normalizes to empty.
      // ponytail: 0.9 damping keeps Jaro-Winkler noise between unrelated
      // titles (~0.6) under the 0.6 cutoff; swap for a stricter title
      // algorithm if junk still leaks through.
      overallScore = titleScore * 0.9;
    } else if (albumScore > 0) {
      overallScore = (titleScore * 0.5) + (artistScore * 0.3) + (albumScore * 0.2);
    } else {
      // No album, reweight
      overallScore = (titleScore * 0.65) + (artistScore * 0.35);
    }
    
    return MatchResult(
      overall: overallScore,
      title: titleScore,
      artist: artistScore,
      album: albumScore,
    );
  }

  /// Calculate title score with partial matching
  static double _calculateTitleScore(String s1, String s2) {
    // Try exact match first
    if (s1 == s2) return 1;

    // An empty side matches nothing (guards `contains('')` scoring 0.9
    // against titles that normalize away entirely).
    if (s1.isEmpty || s2.isEmpty) return 0;

    // Partial (substring) match — score by how much of the longer title the
    // shorter one covers, so "Go With the Flow" (tight) ranks above
    // "Go With the Flow (Live at ...)" (loose) instead of a flat 0.9.
    if (s2.contains(s1) || s1.contains(s2)) {
      final ratio =
          s1.length < s2.length ? s1.length / s2.length : s2.length / s1.length;
      return 0.55 + 0.4 * ratio; // 0.55..0.95
    }
    
    // Use best of multiple algorithms
    final levenshtein = Levenshtein.similarity(s1, s2);
    final jaroWinkler = JaroWinkler.similarity(s1, s2);
    final tokenSort = TokenSortRatio.similarity(s1, s2);
    
    // Return highest score
    return max(levenshtein, max(jaroWinkler, tokenSort));
  }

  /// Calculate artist score
  static double _calculateArtistScore(String s1, String s2) {
    if (s1 == s2) return 1;
    
    // Try token sort for artist names (handles "Queen" vs "Queen Band")
    final tokenSort = TokenSortRatio.similarity(s1, s2);
    final levenshtein = Levenshtein.similarity(s1, s2);
    
    return max(tokenSort, levenshtein);
  }

  /// Normalize string for comparison
  static String _normalize(String s) {
    return s
        .toLowerCase()
        .trim()
        // Remove punctuation, keeping letters/digits in ANY script — Dart's
        // \w is ASCII-only and silently erased Cyrillic titles (#78).
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }
}

/// Result of multi-field fuzzy match
class MatchResult {

  const MatchResult({
    required this.overall,
    required this.title,
    required this.artist,
    required this.album,
  });
  final double overall;
  final double title;
  final double artist;
  final double album;

  /// Get match quality label
  String get quality {
    if (overall >= 0.95) return 'Exact';
    if (overall >= 0.85) return 'Very Close';
    if (overall >= 0.75) return 'Close';
    if (overall >= 0.60) return 'Similar';
    return 'Weak';
  }

  /// Check if this is a good match (>= 0.85)
  bool get isGoodMatch => overall >= 0.85;

  /// Check if this is an exact match (>= 0.95)
  bool get isExactMatch => overall >= 0.95;

  @override
  String toString() {
    return 'MatchResult(overall: ${(overall * 100).toInt()}%, '
        'title: ${(title * 100).toInt()}%, '
        'artist: ${(artist * 100).toInt()}%, '
        'album: ${(album * 100).toInt()}%)';
  }
}
