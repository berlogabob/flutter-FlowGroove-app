/// Musical key normalization for filter matching.
///
/// Stored/entered keys are free-form: sharps or flats ("C#", "Ab"), and
/// minors as a lowercase (or mixed-case) root + trailing 'm' ("cm", "Abm").
/// This canonicalizes any of those forms to a single comparable string so
/// enharmonic equivalents (Ab == G#) and case variants (cm == Cm) match.
library;

/// Flat spelling -> canonical sharp spelling. Mirrors the mapping in
/// `lib/utils/chordpro.dart`'s `_flatToSharp` (kept private there, so this
/// is an independent copy for this module's own use).
const _flatToSharp = {
  'DB': 'C#',
  'EB': 'D#',
  'GB': 'F#',
  'AB': 'G#',
  'BB': 'A#',
  'CB': 'B',
  'FB': 'E',
};

const _validRoots = {'A', 'B', 'C', 'D', 'E', 'F', 'G'};

/// Canonicalizes a musical key string for comparison.
///
/// - Uppercases the root note.
/// - Maps flats to their canonical sharp spelling (Ab -> G#).
/// - Preserves a trailing minor suffix ('m'), e.g. 'cm' -> 'Cm', 'abm' -> 'G#m'.
/// - Returns `null` for `null`, empty, or unparseable input, so callers can
///   treat those as "never matches a specific key filter".
String? canonicalKey(String? key) {
  if (key == null) return null;
  final trimmed = key.trim();
  if (trimmed.isEmpty) return null;

  final isMinor = trimmed.length > 1 && trimmed.toUpperCase().endsWith('M');
  final rootPart = isMinor ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  if (rootPart.isEmpty) return null;

  final rootLetter = rootPart[0].toUpperCase();
  if (!_validRoots.contains(rootLetter)) return null;

  final accidental = rootPart.length > 1 ? rootPart.substring(1) : '';
  String root;
  if (accidental.isEmpty) {
    root = rootLetter;
  } else if (accidental == '#') {
    root = '$rootLetter#';
  } else if (accidental.toUpperCase() == 'B') {
    final flatKey = '$rootLetter${accidental.toUpperCase()}';
    final mapped = _flatToSharp[flatKey];
    if (mapped == null) return null;
    root = mapped;
  } else {
    // Unrecognized accidental (e.g. double sharp/flat) - can't normalize.
    return null;
  }

  return isMinor ? '${root}m' : root;
}

/// Whether [songKey] matches the active [filterKey].
///
/// A null/empty [filterKey] means "no filter", so everything matches. A
/// null/unparseable [songKey] never matches a real filter value - a song
/// with no key shouldn't show up under a specific key chip.
bool keyMatchesFilter(String? songKey, String? filterKey) {
  if (filterKey == null || filterKey.isEmpty) return true;
  final normalizedSong = canonicalKey(songKey);
  if (normalizedSong == null) return false;
  return normalizedSong == canonicalKey(filterKey);
}
