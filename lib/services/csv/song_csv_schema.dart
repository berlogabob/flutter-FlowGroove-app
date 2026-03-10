/// CSV schema definition for song import/export.
///
/// This file defines the standardized CSV format for importing and exporting songs,
/// designed to be compatible with Google Sheets and human-readable.
///
/// Schema follows the pattern:
/// - Core fields: title, artist, keys, BPMs, etc.
/// - Keys are split into components: base, accidental, scale
/// - Sections: section_{n}_{field} (up to 10 sections)
/// - Links: link_{n}_{field} (up to 5 links)
/// - Beat modes: single compact field (metronomePattern)
/// - Tags: comma-separated string
library;

class SongCsvSchema {
  // Core fields (required)
  static const String title = 'title';
  static const String artist = 'artist';

  // Original Key components
  static const String originalKeyBase = 'originalKeyBase';
  static const String originalKeyAccidental = 'originalKeyAccidental';
  static const String originalKeyScale = 'originalKeyScale';

  // Our Key components
  static const String ourKeyBase = 'ourKeyBase';
  static const String ourKeyAccidental = 'ourKeyAccidental';
  static const String ourKeyScale = 'ourKeyScale';

  // Legacy single-field keys (for backward compatibility)
  static const String originalKey = 'originalKey';
  static const String ourKey = 'ourKey';

  static const String originalBPM = 'originalBPM';
  static const String ourBPM = 'ourBPM';
  static const String spotifyUrl = 'spotifyUrl';
  static const String notes = 'notes';
  static const String bandId = 'bandId';
  static const String accentBeats = 'accentBeats';
  static const String regularBeats = 'regularBeats';

  // Tags (comma-separated)
  static const String tags = 'tags';

  // Sections (up to 10 sections)
  static const int maxSections = 10;
  static const List<String> sectionFields = [
    'name',
    'notes',
    'duration',
    'color',
  ];

  // Links (up to 5 links)
  static const int maxLinks = 5;
  static const List<String> linkFields = ['url', 'title', 'type'];

  // Beat modes - compact format (single field)
  // Format: "{{4,2},{[1,0,0,0],[1,0,0,0]}}" where:
  // - {4,2} = accentBeats, regularBeats
  // - [1,0,0,0] = first beat modes (1=accent, 0=normal, 2=silent, 3=rest)
  // - [1,0,0,0] = second beat modes, etc.
  static const String metronomePattern = 'metronomePattern';

  // Valid key bases
  static const List<String> keyBases = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];

  // Valid accidentals
  static const List<String> accidentals = ['', '#', 'b'];

  // Valid scales
  static const List<String> scales = ['major', 'minor'];

  // All header names
  static const List<String> allHeaders = [
    title,
    artist,
    originalKeyBase,
    originalKeyAccidental,
    originalKeyScale,
    ourKeyBase,
    ourKeyAccidental,
    ourKeyScale,
    originalBPM,
    ourBPM,
    spotifyUrl,
    notes,
    bandId,
    accentBeats,
    regularBeats,
    metronomePattern,
    tags,
    // Section headers will be generated dynamically
    // Link headers will be generated dynamically
  ];

  /// Generate all possible section headers
  static List<String> getSectionHeaders() {
    final headers = <String>[];
    for (int i = 1; i <= maxSections; i++) {
      for (final field in sectionFields) {
        headers.add('section_${i}_$field');
      }
    }
    return headers;
  }

  /// Generate all possible link headers
  static List<String> getLinkHeaders() {
    final headers = <String>[];
    for (int i = 1; i <= maxLinks; i++) {
      for (final field in linkFields) {
        headers.add('link_${i}_$field');
      }
    }
    return headers;
  }

  /// Get all headers including dynamic ones
  static List<String> getAllHeaders() {
    final headers = <String>[];
    headers.addAll(allHeaders);
    headers.addAll(getSectionHeaders());
    headers.addAll(getLinkHeaders());
    return headers;
  }

  /// Validate a header name against the schema
  static bool isValidHeader(String header) {
    if (allHeaders.contains(header)) return true;

    // Allow legacy single-field key headers for backward compatibility
    if (header == originalKey || header == ourKey) return true;

    // Allow legacy beat mode headers for backward compatibility
    if (header.startsWith('beatMode_')) return true;

    // Check section headers: section_{n}_{field}
    final sectionMatch = RegExp(r'^section_(\d+)_(\w+)$').firstMatch(header);
    if (sectionMatch != null) {
      final sectionNum = int.tryParse(sectionMatch.group(1)!) ?? 0;
      final field = sectionMatch.group(2)!;
      return sectionNum >= 1 &&
          sectionNum <= maxSections &&
          sectionFields.contains(field);
    }

    // Check link headers: link_{n}_{field}
    final linkMatch = RegExp(r'^link_(\d+)_(\w+)$').firstMatch(header);
    if (linkMatch != null) {
      final linkNum = int.tryParse(linkMatch.group(1)!) ?? 0;
      final field = linkMatch.group(2)!;
      return linkNum >= 1 && linkNum <= maxLinks && linkFields.contains(field);
    }

    return false;
  }

  /// Encode beat modes to compact string format.
  /// Format: "{{4,2},{[1,0,0,0],[1,0,0,0]}}"
  static String encodeBeatModes(
    List<List<int>> beatModes,
    int accentBeats,
    int regularBeats,
  ) {
    if (beatModes.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    buffer.write('{$accentBeats,$regularBeats},{');

    for (int i = 0; i < beatModes.length; i++) {
      if (i > 0) buffer.write(',');
      buffer.write('[');
      for (int j = 0; j < beatModes[i].length; j++) {
        if (j > 0) buffer.write(',');
        buffer.write(beatModes[i][j]);
      }
      buffer.write(']');
    }

    buffer.write('}');
    return buffer.toString();
  }

  /// Decode beat modes from compact string format.
  /// Format: "{{4,2},{[1,0,0,0],[1,0,0,0]}}"
  static Map<String, dynamic>? decodeBeatModes(String? pattern) {
    if (pattern == null || pattern.isEmpty) {
      return null;
    }

    try {
      // Parse: {{4,2},{[1,0,0,0],[1,0,0,0]}}
      final outerMatch = RegExp(
        r'\{(\d+),(\d+)\},\{(.+)\}',
      ).firstMatch(pattern);
      if (outerMatch == null) return null;

      final accentBeats = int.parse(outerMatch.group(1)!);
      final regularBeats = int.parse(outerMatch.group(2)!);
      final rowsStr = outerMatch.group(3)!;

      final beatModes = <List<int>>[];

      // Parse each row: [1,0,0,0],[1,0,0,0]
      final rowMatches = RegExp(r'\[([\d,]+)\]').allMatches(rowsStr);
      for (final match in rowMatches) {
        final values = match
            .group(1)!
            .split(',')
            .map((v) => int.parse(v.trim()))
            .toList();
        beatModes.add(values);
      }

      return {
        'accentBeats': accentBeats,
        'regularBeats': regularBeats,
        'beatModes': beatModes,
      };
    } catch (e) {
      return null;
    }
  }

  /// Get required headers (core fields that must be present)
  static const List<String> requiredHeaders = [title, artist];

  /// Parse a key string (e.g., "C#m", "Bb") into components
  static Map<String, String?> parseKeyString(String? key) {
    if (key == null || key.isEmpty) {
      return {'base': null, 'accidental': null, 'scale': null};
    }

    var trimmedKey = key.trim();
    String? base;
    String? accidental;
    String? scale;

    // Extract base note (first character)
    if (trimmedKey.isNotEmpty) {
      base = trimmedKey[0].toUpperCase();
    }

    // Check for accidental (second character if # or b)
    if (key.length > 1 && (key[1] == '#' || key[1] == 'b')) {
      accidental = key[1];
    }

    // Check for scale (minor if ends with 'm')
    if (key.endsWith('m')) {
      scale = 'minor';
    } else {
      scale = 'major';
    }

    return {'base': base, 'accidental': accidental, 'scale': scale};
  }

  /// Build a key string from components
  static String buildKeyString({
    required String base,
    String? accidental,
    required String scale,
  }) {
    String result = base.toUpperCase();
    if (accidental != null && accidental.isNotEmpty) {
      result += accidental;
    }
    if (scale.toLowerCase() == 'minor') {
      result += 'm';
    }
    return result;
  }
}

/// Validation rules for CSV data
class SongCsvValidation {
  /// Validate BPM value (must be integer between 40-300)
  static bool isValidBpm(dynamic value) {
    if (value == null || value.toString().isEmpty) return true; // Optional
    final bpm = int.tryParse(value.toString());
    return bpm != null && bpm >= 40 && bpm <= 300;
  }

  /// Validate key base (A-G)
  static bool isValidKeyBase(String? base) {
    if (base == null || base.isEmpty) return true;
    return SongCsvSchema.keyBases.contains(base.toUpperCase());
  }

  /// Validate accidental (empty, #, or b)
  static bool isValidAccidental(String? accidental) {
    if (accidental == null) return true;
    return SongCsvSchema.accidentals.contains(accidental);
  }

  /// Validate scale (major or minor)
  static bool isValidScale(String? scale) {
    if (scale == null || scale.isEmpty) return true;
    return SongCsvSchema.scales.contains(scale.toLowerCase());
  }

  /// Validate legacy key format (e.g., "C", "G#", "Am", "Bbm")
  static bool isValidKey(String? key) {
    if (key == null || key.isEmpty) return true; // Optional
    return RegExp(r'^[A-G][#b]?m?$').hasMatch(key);
  }

  /// Validate URL format
  static bool isValidUrl(String? url) {
    if (url == null || url.isEmpty) return true; // Optional
    try {
      Uri.parse(url);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Validate color format (ARGB hex: FF42A5F5 or #42A5F5)
  static bool isValidColor(String? color) {
    if (color == null || color.isEmpty) return true; // Optional
    return RegExp(r'^#?[A-Fa-f0-9]{6,8}$').hasMatch(color);
  }

  /// Validate beat mode value (accent, normal, silent, rest)
  static bool isValidBeatMode(String? mode) {
    if (mode == null || mode.isEmpty) return true; // Optional
    final validModes = {'accent', 'normal', 'silent', 'rest'};
    return validModes.contains(mode.toLowerCase());
  }

  /// Validate duration (positive number)
  static bool isValidDuration(dynamic value) {
    if (value == null || value.toString().isEmpty) return true; // Optional
    final duration = double.tryParse(value.toString());
    return duration != null && duration > 0;
  }
}
