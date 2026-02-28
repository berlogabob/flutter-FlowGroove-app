/// String normalization utilities for song matching.
///
/// This library provides comprehensive string normalization for fuzzy matching
/// of song titles and artist names. It handles:
/// - Case folding
/// - Special character removal
/// - Article prefix removal ("The")
/// - Feature/collaboration removal ("feat.", "ft.", etc.)
/// - Version suffix removal ("Remastered", "Live", etc.)
/// - Parenthetical content removal
/// - Whitespace normalization
library;

/// Normalizes a string for fuzzy matching.
class SongNormalizer {
  /// Normalizes a song title for comparison.
  ///
  /// Applies the full normalization pipeline:
  /// 1. Lowercase conversion
  /// 2. Parenthetical content removal (before special char removal)
  /// 3. Feature removal
  /// 4. Version suffix removal
  /// 5. Special character removal
  /// 6. Whitespace normalization
  static String normalizeTitle(String title) {
    if (title.isEmpty) return '';

    var result = title;

    // Step 1: Lowercase
    result = result.toLowerCase();

    // Step 2: Remove parenthetical content (BEFORE special char removal)
    result = _removeParentheticalContent(result);

    // Step 3: Remove features
    result = _removeFeatures(result);

    // Step 4: Remove version suffixes
    result = _removeVersionSuffixes(result);

    // Step 5: Remove special characters (keep alphanumeric, spaces, hyphens)
    result = result.replaceAll(RegExp(r'[^\w\s\-]'), ' ');

    // Step 6: Final whitespace cleanup
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

    return result;
  }

  /// Normalizes an artist name for comparison.
  ///
  /// Similar to [normalizeTitle] but with artist-specific handling:
  /// - Removes "The" prefix
  /// - Normalizes "and" to "&"
  static String normalizeArtist(String artist) {
    if (artist.isEmpty) return '';

    var result = artist;

    // Step 1: Lowercase
    result = result.toLowerCase();

    // Step 2: Remove special characters
    result = result.replaceAll(RegExp(r'[^\w\s\-&]'), ' ');

    // Step 3: Remove "The" prefix
    result = result.replaceFirst(RegExp(r'^the\s+'), '');

    // Step 4: Normalize "and" to "&"
    result = result.replaceAll(RegExp(r'\s+and\s+'), ' & ');

    // Step 5: Normalize ampersand spacing
    result = result.replaceAll(RegExp(r'\s*&\s*'), '&');

    // Step 6: Final whitespace cleanup
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

    return result;
  }

  /// Removes feature/collaboration indicators from a string.
  static String _removeFeatures(String input) {
    final patterns = [
      RegExp(r'\s+feat\.?\s+.*$'),
      RegExp(r'\s+ft\.?\s+.*$'),
      RegExp(r'\s+featuring\s+.*$'),
      RegExp(r'\s+with\s+.*$'),
      RegExp(r'\s+vs\.?\s+.*$'),
      RegExp(r'\s+x\s+.*$'),
    ];

    var result = input;
    for (final pattern in patterns) {
      result = result.replaceAll(pattern, '');
    }
    return result.trim();
  }

  /// Removes version suffixes from a string.
  static String _removeVersionSuffixes(String input) {
    final patterns = [
      RegExp(r'\s*-\s*remastered\s*(\d{4})?\s*$'),
      RegExp(r'\s*-\s*remaster\s*$'),
      RegExp(r'\s*-\s*remix\s*$'),
      RegExp(r'\s*-\s*radio\s+edit\s*$'),
      RegExp(r'\s*-\s*album\s+version\s*$'),
      RegExp(r'\s*-\s*single\s+version\s*$'),
      RegExp(r'\s*-\s*extended\s+mix\s*$'),
      RegExp(r'\s*-\s*clean\s+version\s*$'),
      RegExp(r'\s*-\s*explicit\s+version\s*$'),
    ];

    var result = input;
    for (final pattern in patterns) {
      result = result.replaceAll(pattern, '');
    }
    return result.trim();
  }

  /// Removes parenthetical content from a string.
  static String _removeParentheticalContent(String input) {
    final patterns = [
      // Specific patterns first
      RegExp(r'\s*\(live\s+version\)', caseSensitive: false),
      RegExp(r'\s*\(live\s+at\s+.*\)', caseSensitive: false),
      RegExp(r'\s*\(acoustic\s+version\)', caseSensitive: false),
      RegExp(r'\s*\(karaoke\s+version\)', caseSensitive: false),
      RegExp(r'\s*\(album\s+version\)', caseSensitive: false),
      RegExp(r'\s*\(single\s+version\)', caseSensitive: false),
      RegExp(r'\s*\(radio\s+edit\)', caseSensitive: false),
      RegExp(r'\s*\(feat\.?\s+.*\)', caseSensitive: false),
      RegExp(r'\s*\(ft\.?\s+.*\)', caseSensitive: false),
      RegExp(r'\s*\(featuring\s+.*\)', caseSensitive: false),
      // General patterns
      RegExp(r'\s*\(live\)', caseSensitive: false),
      RegExp(r'\s*\(acoustic\)', caseSensitive: false),
      RegExp(r'\s*\(unplugged\)', caseSensitive: false),
      RegExp(r'\s*\(instrumental\)', caseSensitive: false),
      RegExp(r'\s*\(cover\)', caseSensitive: false),
      RegExp(r'\s*\(demo\)', caseSensitive: false),
      RegExp(r'\s*\(remix\)', caseSensitive: false),
      RegExp(r'\s*\(remastered\)', caseSensitive: false),
      RegExp(r'\s*\(re-recording\)', caseSensitive: false),
      RegExp(r'\s*\(re-recorded\)', caseSensitive: false),
      RegExp(r'\s*\(version\s+.*\)', caseSensitive: false),
    ];

    var result = input;
    for (final pattern in patterns) {
      result = result.replaceAll(pattern, '');
    }

    // Remove empty parentheses
    result = result.replaceAll(RegExp(r'\s*\(\s*\)'), '');

    return result.trim();
  }
}
