/// Validator class for song form fields.
///
/// Provides validation methods for all form inputs in the add/edit
/// song screen. Each method returns an error message string if
/// validation fails, or null if validation passes.
class SongFormValidator {
  /// Validate the song title.
  ///
  /// Returns an error message if title is empty, null otherwise.
  static String? validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Title required';
    }
    return null;
  }

  /// Validate the artist name.
  ///
  /// Artist is optional, so this always returns null.
  static String? validateArtist(String? value) {
    return null;
  }

  /// Validate BPM input.
  ///
  /// Returns an error message if BPM is not a valid positive number,
  /// null otherwise. Empty BPM is allowed (optional field).
  static String? validateBpm(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // BPM is optional
    }
    final bpm = int.tryParse(value.trim());
    if (bpm == null) {
      return 'Invalid BPM';
    }
    if (bpm <= 0) {
      return 'BPM must be positive';
    }
    if (bpm > 300) {
      return 'BPM seems too high';
    }
    return null;
  }

  /// Validate a URL.
  ///
  /// Returns an error message if URL is invalid, null otherwise.
  /// Empty URL is allowed (optional field).
  static String? validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // URL is optional
    }
    try {
      Uri.parse(value.trim());
      return null;
    } catch (_) {
      return 'Invalid URL';
    }
  }

  /// Validate notes field.
  ///
  /// Notes are optional, so this always returns null.
  static String? validateNotes(String? value) {
    return null;
  }

  /// Validate that at least one tag is selected.
  ///
  /// Returns an error message if no tags selected, null otherwise.
  static String? validateTags(List<String> tags) {
    if (tags.isEmpty) {
      return 'Select at least one tag';
    }
    return null;
  }

  /// Validate key selection.
  ///
  /// Key is optional, so this always returns null.
  static String? validateKey(String base, String modifier) {
    return null;
  }
}
