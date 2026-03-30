import 'dart:math';

/// Fuzzy string matcher for song search and deduplication
/// 
/// Provides various string similarity algorithms to match song titles
/// and artists even with typos, variations, or incomplete data.
/// 
/// Usage:
/// ```dart
/// final score = FuzzyMatcher.ratio('Bohemian Rhapsody', 'Bohemian Rapsody');
/// // score ≈ 0.95 (high similarity despite typo)
/// ```
class FuzzyMatcher {
  /// Calculate similarity ratio between two strings (0.0-1.0)
  /// 
  /// Uses Levenshtein distance algorithm.
  /// 1.0 = exact match, 0.0 = completely different
  /// 
  /// Example:
  /// ```dart
  /// FuzzyMatcher.ratio('hello', 'hello') // 1.0
  /// FuzzyMatcher.ratio('hello', 'hallo') // 0.8
  /// FuzzyMatcher.ratio('hello', 'world') // 0.2
  /// ```
  static double ratio(String s1, String s2) {
    if (s1.isEmpty && s2.isEmpty) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    
    final distance = _levenshteinDistance(s1, s2);
    final maxLength = max(s1.length, s2.length);
    
    return 1.0 - (distance / maxLength);
  }

  /// Partial ratio - finds best matching substring
  /// 
  /// Useful when one string is much longer than the other.
  /// Slides a window over the longer string and finds best match.
  /// 
  /// Example:
  /// ```dart
  /// FuzzyMatcher.partialRatio('Bohemian Rhapsody', 
  ///   'Queen - Bohemian Rhapsody (Remaster)') // High score
  /// ```
  static double partialRatio(String s1, String s2) {
    if (s1.isEmpty && s2.isEmpty) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    
    final short = s1.length < s2.length ? s1 : s2;
    final long = s1.length < s2.length ? s2 : s1;
    
    // If short is contained in long, perfect match
    if (long.toLowerCase().contains(short.toLowerCase())) {
      return 1.0;
    }
    
    // Slide window over long string
    var bestScore = 0.0;
    final windowSize = short.length;
    
    for (var i = 0; i <= long.length - windowSize; i++) {
      final substring = long.substring(i, i + windowSize);
      final score = ratio(short, substring);
      if (score > bestScore) {
        bestScore = score;
      }
    }
    
    return bestScore;
  }

  /// Token sort ratio - word order independent
  /// 
  /// Splits strings into words, sorts them, then compares.
  /// Useful for "Queen - Bohemian Rhapsody" vs "Bohemian Rhapsody by Queen"
  /// 
  /// Example:
  /// ```dart
  /// FuzzyMatcher.tokenSortRatio(
  ///   'Queen Bohemian Rhapsody',
  ///   'Bohemian Rhapsody Queen'
  /// ) // High score despite word order
  /// ```
  static double tokenSortRatio(String s1, String s2) {
    if (s1.isEmpty && s2.isEmpty) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    
    final words1 = _tokenize(s1);
    final words2 = _tokenize(s2);
    
    words1.sort();
    words2.sort();
    
    final joined1 = words1.join(' ');
    final joined2 = words2.join(' ');
    
    return ratio(joined1, joined2);
  }

  /// Token set ratio - handles duplicate words
  /// 
  /// Similar to token sort but removes duplicate words.
  /// Better for "Queen Queen Bohemian Rhapsody" vs "Queen Bohemian Rhapsody"
  static double tokenSetRatio(String s1, String s2) {
    if (s1.isEmpty && s2.isEmpty) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    
    final words1 = _tokenize(s1).toSet().toList();
    final words2 = _tokenize(s2).toSet().toList();
    
    words1.sort();
    words2.sort();
    
    final joined1 = words1.join(' ');
    final joined2 = words2.join(' ');
    
    return ratio(joined1, joined2);
  }

  /// Calculate multi-field match score
  /// 
  /// Combines multiple field comparisons with weights:
  /// - Title: 50%
  /// - Artist: 30%
  /// - Album: 20%
  /// 
  /// Returns overall match score (0.0-1.0) and individual scores.
  static MatchResult calculateMatchScore({
    required String inputTitle,
    required String inputArtist,
    String? inputAlbum,
    required String targetTitle,
    required String targetArtist,
    String? targetAlbum,
  }) {
    // Normalize inputs
    final normInputTitle = _normalize(inputTitle);
    final normInputArtist = _normalize(inputArtist);
    final normInputAlbum = _normalize(inputAlbum ?? '');
    
    final normTargetTitle = _normalize(targetTitle);
    final normTargetArtist = _normalize(targetArtist);
    final normTargetAlbum = _normalize(targetAlbum ?? '');
    
    // Calculate individual scores
    final titleScore = ratio(normInputTitle, normTargetTitle);
    final artistScore = ratio(normInputArtist, normTargetArtist);
    final albumScore = targetAlbum != null && targetAlbum.isNotEmpty
        ? ratio(normInputAlbum, normTargetAlbum)
        : 0.0;
    
    // Weighted average
    double overallScore;
    
    if (albumScore > 0) {
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

  /// Check if strings sound similar (phonetic matching)
  /// 
  /// Uses simple soundex-like algorithm.
  static bool soundsLike(String s1, String s2) {
    if (s1.isEmpty || s2.isEmpty) return false;
    
    final soundex1 = _soundex(s1);
    final soundex2 = _soundex(s2);
    
    return soundex1 == soundex2;
  }

  /// Levenshtein distance implementation
  static int _levenshteinDistance(String s1, String s2) {
    final m = s1.length;
    final n = s2.length;
    
    // Create distance matrix
    final dp = List.generate(
      m + 1,
      (i) => List.generate(n + 1, (j) => 0),
    );
    
    // Initialize base cases
    for (var i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= n; j++) {
      dp[0][j] = j;
    }
    
    // Fill matrix
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        dp[i][j] = min(
          dp[i - 1][j] + 1, // deletion
          min(
            dp[i][j - 1] + 1, // insertion
            dp[i - 1][j - 1] + cost, // substitution
          ),
        );
        
        // Transposition (Damerau-Levenshtein)
        if (i > 1 &&
            j > 1 &&
            s1[i - 1] == s2[j - 2] &&
            s1[i - 2] == s2[j - 1]) {
          dp[i][j] = min(dp[i][j], dp[i - 2][j - 2] + cost);
        }
      }
    }
    
    return dp[m][n];
  }

  /// Tokenize string into words
  static List<String> _tokenize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
  }

  /// Normalize string for comparison
  static String _normalize(String s) {
    return s
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .replaceAll(RegExp(r'\s+'), ' '); // Normalize whitespace
  }

  /// Simple Soundex implementation
  static String _soundex(String s) {
    if (s.isEmpty) return '';
    
    s = s.toUpperCase();
    final firstLetter = s[0];
    
    // Coding rules
    final codes = {
      'B': '1', 'F': '1', 'P': '1', 'V': '1',
      'C': '2', 'G': '2', 'J': '2', 'K': '2', 'Q': '2', 'S': '2', 'X': '2', 'Z': '2',
      'D': '3', 'T': '3',
      'L': '4',
      'M': '5', 'N': '5',
      'R': '6',
    };
    
    var result = firstLetter;
    String? lastCode;
    
    for (var i = 1; i < s.length && result.length < 4; i++) {
      final char = s[i];
      final code = codes[char];
      
      if (code != null && code != lastCode) {
        result += code;
      }
      
      lastCode = code;
    }
    
    // Pad with zeros
    while (result.length < 4) {
      result += '0';
    }
    
    return result;
  }
}

/// Result of multi-field fuzzy match
class MatchResult {
  final double overall;
  final double title;
  final double artist;
  final double album;

  const MatchResult({
    required this.overall,
    required this.title,
    required this.artist,
    required this.album,
  });

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
