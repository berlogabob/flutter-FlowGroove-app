/// Shared catalogue of song tags plus a normaliser.
///
/// Tags are stored lowercase and single-spaced so that filtering and the tag
/// cloud never treat "Learning" and "learning" as two different tags.
class SongTags {
  SongTags._();

  /// Learning / readiness status shown on a song card.
  static const List<String> learningStatus = ['to learn', 'learning', 'ready'];

  /// Difficulty / tempo descriptors.
  static const List<String> descriptors = ['easy', 'hard', 'slow', 'fast'];

  /// All predefined suggestions, in display order.
  static const List<String> predefined = [...learningStatus, ...descriptors];

  /// Normalises a single tag for storage/comparison.
  static String normalize(String tag) =>
      tag.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Normalises and de-duplicates a list of tags, preserving first-seen order.
  static List<String> normalizeAll(Iterable<String> tags) {
    final seen = <String>{};
    final result = <String>[];
    for (final tag in tags) {
      final normalized = normalize(tag);
      if (normalized.isNotEmpty && seen.add(normalized)) {
        result.add(normalized);
      }
    }
    return result;
  }
}
