/// Simple CSV parser for song import/export.
///
/// This service handles parsing CSV data into Song objects,
/// with validation and error reporting.
library;

import 'package:csv/csv.dart';
import 'package:flutter_repsync_app/models/song.dart';
import 'package:flutter_repsync_app/models/section.dart';
import 'package:flutter_repsync_app/models/link.dart';
import '../../models/beat_mode.dart';
import 'package:uuid/uuid.dart';
import 'song_csv_schema.dart';

const Uuid _uuid = Uuid();

class SongCsvParser {
  /// Parse CSV string into a list of Song objects.
  ///
  /// Returns [SongParseResult] containing successful songs and errors.
  SongParseResult parse(String csvContent) {
    try {
      // Handle BOM if present (UTF-8 BOM: EF BB BF)
      final content = csvContent.startsWith('\uFEFF')
          ? csvContent.substring(1)
          : csvContent;

      if (content.trim().isEmpty) {
        return SongParseResult(successful: [], errors: ['CSV is empty']);
      }

      // Use csv.decode() from package:csv/csv.dart
      final rows = csv.decode(content);

      if (rows.isEmpty) {
        return SongParseResult(successful: [], errors: ['CSV is empty']);
      }

      // Convert all values to strings for consistent handling
      final stringRows = rows
          .where((row) => row.isNotEmpty)
          .map((row) => row.map((cell) => cell?.toString() ?? '').toList())
          .toList();

      // Parse headers from first row
      final headers = stringRows[0];
      if (headers.isEmpty) {
        return SongParseResult(successful: [], errors: ['Invalid header line']);
      }

      final result = SongParseResult(successful: [], errors: []);

      // Validate headers
      final headerValidation = _validateHeaders(headers);
      if (headerValidation.isNotEmpty) {
        result.errors.addAll(headerValidation);
        return result;
      }

      // Parse each data row (skip header row)
      for (int rowIndex = 1; rowIndex < stringRows.length; rowIndex++) {
        try {
          final row = stringRows[rowIndex];
          final songResult = _parseRow(
            row,
            headers,
            rowIndex + 1,
          ); // 1-based line numbers
          if (songResult.success != null) {
            result.successful.add(songResult.success!);
          } else {
            result.errors.addAll(
              songResult.errors.map((e) => 'Row ${rowIndex + 1}: $e'),
            );
          }
        } catch (e, stackTrace) {
          result.errors.add(
            'Row ${rowIndex + 1}: Parse error: $e\n$stackTrace',
          );
        }
      }

      return result;
    } catch (e, stackTrace) {
      return SongParseResult(
        successful: [],
        errors: ['CSV parsing failed: $e\n$stackTrace'],
      );
    }
  }

  /// Validate CSV headers against the schema.
  List<String> _validateHeaders(List<String> headers) {
    final errors = <String>[];

    // Check required headers
    for (final requiredHeader in SongCsvSchema.requiredHeaders) {
      if (!headers.contains(requiredHeader)) {
        errors.add('Missing required header: "$requiredHeader"');
      }
    }

    // Check for invalid headers
    for (final header in headers) {
      if (!SongCsvSchema.isValidHeader(header)) {
        errors.add('Invalid header: "$header"');
      }
    }

    return errors;
  }

  /// Parse a single row into a Song object.
  SongParseResultItem _parseRow(
    List<String> row,
    List<String> headers,
    int lineNumber,
  ) {
    final errors = <String>[];
    final songData = <String, dynamic>{};

    // Map headers to values
    for (int i = 0; i < headers.length && i < row.length; i++) {
      songData[headers[i]] = row[i];
    }

    // Parse core fields
    final title = _getStringValue(
      songData,
      SongCsvSchema.title,
      errors,
      lineNumber,
    );
    final artist = _getStringValue(
      songData,
      SongCsvSchema.artist,
      errors,
      lineNumber,
    );

    if (title == null || artist == null) {
      return SongParseResultItem(errors: ['Title and artist are required']);
    }

    // Parse optional core fields
    // Support both new split format and legacy single-field format
    String? originalKey;
    String? ourKey;

    // Try new split format first
    final originalKeyBase = _getStringValue(
      songData,
      SongCsvSchema.originalKeyBase,
      errors,
      lineNumber,
    );
    final originalKeyAccidental = _getStringValue(
      songData,
      SongCsvSchema.originalKeyAccidental,
      errors,
      lineNumber,
    );
    final originalKeyScale = _getStringValue(
      songData,
      SongCsvSchema.originalKeyScale,
      errors,
      lineNumber,
    );

    if (originalKeyBase != null) {
      // Validate split components
      if (!SongCsvValidation.isValidKeyBase(originalKeyBase)) {
        errors.add(
          'Invalid key base at line $lineNumber: "$originalKeyBase" (must be A-G)',
        );
      }
      if (!SongCsvValidation.isValidAccidental(originalKeyAccidental)) {
        errors.add(
          'Invalid accidental at line $lineNumber: "$originalKeyAccidental" (must be empty, #, or b)',
        );
      }
      if (!SongCsvValidation.isValidScale(originalKeyScale)) {
        errors.add(
          'Invalid scale at line $lineNumber: "$originalKeyScale" (must be major or minor)',
        );
      }

      // Use split format
      originalKey = SongCsvSchema.buildKeyString(
        base: originalKeyBase,
        accidental: originalKeyAccidental,
        scale: originalKeyScale ?? 'major',
      );
    } else {
      // Fall back to legacy format
      originalKey = _getStringValue(
        songData,
        SongCsvSchema.originalKey,
        errors,
        lineNumber,
      );
      if (!SongCsvValidation.isValidKey(originalKey)) {
        errors.add('Invalid key format at line $lineNumber: "$originalKey"');
      }
    }

    // Parse "our" key
    final ourKeyBase = _getStringValue(
      songData,
      SongCsvSchema.ourKeyBase,
      errors,
      lineNumber,
    );
    final ourKeyAccidental = _getStringValue(
      songData,
      SongCsvSchema.ourKeyAccidental,
      errors,
      lineNumber,
    );
    final ourKeyScale = _getStringValue(
      songData,
      SongCsvSchema.ourKeyScale,
      errors,
      lineNumber,
    );

    if (ourKeyBase != null) {
      // Validate split components
      if (!SongCsvValidation.isValidKeyBase(ourKeyBase)) {
        errors.add(
          'Invalid key base at line $lineNumber: "$ourKeyBase" (must be A-G)',
        );
      }
      if (!SongCsvValidation.isValidAccidental(ourKeyAccidental)) {
        errors.add(
          'Invalid accidental at line $lineNumber: "$ourKeyAccidental" (must be empty, #, or b)',
        );
      }
      if (!SongCsvValidation.isValidScale(ourKeyScale)) {
        errors.add(
          'Invalid scale at line $lineNumber: "$ourKeyScale" (must be major or minor)',
        );
      }

      // Use split format
      ourKey = SongCsvSchema.buildKeyString(
        base: ourKeyBase,
        accidental: ourKeyAccidental,
        scale: ourKeyScale ?? 'major',
      );
    } else {
      // Fall back to legacy format
      ourKey = _getStringValue(
        songData,
        SongCsvSchema.ourKey,
        errors,
        lineNumber,
      );
      if (!SongCsvValidation.isValidKey(ourKey)) {
        errors.add('Invalid key format at line $lineNumber: "$ourKey"');
      }
    }

    final originalBPM = _getIntValue(
      songData,
      SongCsvSchema.originalBPM,
      errors,
      lineNumber,
    );
    final ourBPM = _getIntValue(
      songData,
      SongCsvSchema.ourBPM,
      errors,
      lineNumber,
    );

    final spotifyUrl = _getStringValue(
      songData,
      SongCsvSchema.spotifyUrl,
      errors,
      lineNumber,
    );
    final notes = _getStringValue(
      songData,
      SongCsvSchema.notes,
      errors,
      lineNumber,
    );
    final bandId = _getStringValue(
      songData,
      SongCsvSchema.bandId,
      errors,
      lineNumber,
    );

    final accentBeats =
        _getIntValue(songData, SongCsvSchema.accentBeats, errors, lineNumber) ??
        4;
    final regularBeats =
        _getIntValue(
          songData,
          SongCsvSchema.regularBeats,
          errors,
          lineNumber,
        ) ??
        1;

    // Parse tags
    final tagsStr = _getStringValue(
      songData,
      SongCsvSchema.tags,
      errors,
      lineNumber,
    );
    final tags =
        tagsStr
            ?.split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList() ??
        [];

    // Parse sections
    final sections = _parseSections(songData, errors, lineNumber);

    // Parse links
    final links = _parseLinks(songData, errors, lineNumber);

    // Parse beat modes - try new compact format first, fall back to legacy
    List<List<BeatMode>> beatModes;
    final metronomePattern = _getStringValue(
      songData,
      SongCsvSchema.metronomePattern,
      errors,
      lineNumber,
    );

    if (metronomePattern != null && metronomePattern.isNotEmpty) {
      // New compact format
      final decoded = SongCsvSchema.decodeBeatModes(metronomePattern);
      if (decoded != null) {
        beatModes = _convertIntBeatModesToEnum(
          decoded['beatModes'] as List<List<int>>,
        );
      } else {
        beatModes = _createDefaultBeatModes(accentBeats, regularBeats);
        errors.add(
          'Invalid metronome pattern at line $lineNumber: "$metronomePattern"',
        );
      }
    } else {
      // Legacy format (individual beatMode_X_Y columns)
      beatModes = _parseBeatModes(
        songData,
        accentBeats,
        regularBeats,
        errors,
        lineNumber,
      );
    }

    // Create song
    if (errors.isNotEmpty) {
      return SongParseResultItem(errors: errors);
    }

    try {
      final song = Song(
        id: _uuid.v4(), // Generate unique ID
        title: title,
        artist: artist,
        originalKey: originalKey,
        originalBPM: originalBPM,
        ourKey: ourKey,
        ourBPM: ourBPM,
        links: links,
        notes: notes,
        tags: tags,
        bandId: bandId,
        spotifyUrl: spotifyUrl,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        accentBeats: accentBeats,
        regularBeats: regularBeats,
        beatModes: beatModes,
        sections: sections,
      );
      return SongParseResultItem(success: song);
    } catch (e) {
      return SongParseResultItem(errors: ['Failed to create Song: $e']);
    }
  }

  /// Parse sections from CSV data
  List<Section> _parseSections(
    Map<String, dynamic> data,
    List<String> errors,
    int lineNumber,
  ) {
    final sections = <Section>[];

    for (int i = 1; i <= SongCsvSchema.maxSections; i++) {
      final name = _getStringValue(
        data,
        'section_${i}_name',
        errors,
        lineNumber,
      );
      if (name == null) continue; // Skip empty sections

      final notes = _getStringValue(
        data,
        'section_${i}_notes',
        errors,
        lineNumber,
      );
      final durationStr = _getStringValue(
        data,
        'section_${i}_duration',
        errors,
        lineNumber,
      );
      final color = _getStringValue(
        data,
        'section_${i}_color',
        errors,
        lineNumber,
      );

      int? duration;
      if (durationStr != null) {
        duration = int.tryParse(durationStr);
        if (duration == null || duration <= 0) {
          errors.add(
            'Invalid duration for section $i: "$durationStr" at line $lineNumber',
          );
        }
      }

      int? colorValue;
      if (color != null && color.isNotEmpty) {
        colorValue = _parseColorValue(color, errors, lineNumber, 'section $i');
      }

      sections.add(
        Section(
          id: '', // Will be generated later
          name: name,
          notes: notes ?? '',
          duration: duration ?? 1,
          colorValue: colorValue,
        ),
      );
    }

    return sections;
  }

  /// Parse color value from string (supports #RRGGBB, RRGGBB, AARRGGBB formats)
  int? _parseColorValue(
    String color,
    List<String> errors,
    int lineNumber,
    String context,
  ) {
    try {
      var hex = color.trim();
      if (hex.startsWith('#')) {
        hex = hex.substring(1);
      }

      // Pad to 8 characters if needed (add FF alpha)
      if (hex.length == 6) {
        hex = 'FF$hex';
      }

      if (hex.length != 8) {
        errors.add(
          'Invalid color format for $context: "$color" at line $lineNumber',
        );
        return null;
      }

      return int.parse(hex, radix: 16);
    } catch (e) {
      errors.add(
        'Invalid color format for $context: "$color" at line $lineNumber',
      );
      return null;
    }
  }

  /// Parse links from CSV data
  List<Link> _parseLinks(
    Map<String, dynamic> data,
    List<String> errors,
    int lineNumber,
  ) {
    final links = <Link>[];

    for (int i = 1; i <= SongCsvSchema.maxLinks; i++) {
      final url = _getStringValue(data, 'link_${i}_url', errors, lineNumber);
      if (url == null) continue; // Skip empty links

      final title =
          _getStringValue(data, 'link_${i}_title', errors, lineNumber) ?? url;
      final type =
          _getStringValue(data, 'link_${i}_type', errors, lineNumber) ??
          'other';

      if (!SongCsvValidation.isValidUrl(url)) {
        errors.add('Invalid URL for link $i: "$url" at line $lineNumber');
      }

      links.add(Link(url: url, type: type, title: title));
    }

    return links;
  }

  /// Parse beat modes from CSV data
  List<List<BeatMode>> _parseBeatModes(
    Map<String, dynamic> data,
    int accentBeats,
    int regularBeats,
    List<String> errors,
    int lineNumber,
  ) {
    final beatModes = <List<BeatMode>>[];

    // Initialize with default values
    for (int i = 0; i < accentBeats; i++) {
      final row = <BeatMode>[];
      for (int j = 0; j < regularBeats; j++) {
        row.add(BeatMode.normal);
      }
      beatModes.add(row);
    }

    // Override with CSV values (legacy format: beatMode_0_0, beatMode_0_1, etc.)
    for (int row = 0; row < accentBeats; row++) {
      for (int col = 0; col < regularBeats; col++) {
        final header = 'beatMode_${row}_$col';
        final modeStr = _getStringValue(data, header, errors, lineNumber);

        if (modeStr != null) {
          if (!SongCsvValidation.isValidBeatMode(modeStr)) {
            errors.add(
              'Invalid beat mode for $header: "$modeStr" at line $lineNumber',
            );
            continue;
          }

          final mode = BeatMode.values.firstWhere(
            (m) => m.name.toLowerCase() == modeStr.toLowerCase(),
            orElse: () => BeatMode.normal,
          );

          // Only apply if within bounds
          if (row < beatModes.length && col < beatModes[row].length) {
            beatModes[row][col] = mode;
          }
        }
      }
    }

    return beatModes;
  }

  /// Get string value from data map, add error if missing and required
  String? _getStringValue(
    Map<String, dynamic> data,
    String key,
    List<String> errors,
    int lineNumber,
  ) {
    final value = data[key];
    if (value == null || value.toString().isEmpty) {
      return null;
    }
    return value.toString();
  }

  /// Get int value from data map, add error if invalid
  int? _getIntValue(
    Map<String, dynamic> data,
    String key,
    List<String> errors,
    int lineNumber,
  ) {
    final value = data[key];
    if (value == null || value.toString().isEmpty) {
      return null;
    }

    final intValue = int.tryParse(value.toString());
    if (intValue == null) {
      errors.add(
        'Invalid integer value for "$key": $value at line $lineNumber',
      );
      return null;
    }

    return intValue;
  }

  /// Convert integer beat modes to BeatMode enum
  List<List<BeatMode>> _convertIntBeatModesToEnum(List<List<int>> intModes) {
    return intModes
        .map(
          (row) => row.map((value) {
            switch (value) {
              case 1:
                return BeatMode.accent;
              case 2:
                return BeatMode.silent;
              default:
                return BeatMode.normal;
            }
          }).toList(),
        )
        .toList();
  }

  /// Create default beat modes grid
  List<List<BeatMode>> _createDefaultBeatModes(
    int accentBeats,
    int regularBeats,
  ) {
    final beatModes = <List<BeatMode>>[];
    for (int i = 0; i < accentBeats; i++) {
      final row = <BeatMode>[];
      for (int j = 0; j < regularBeats; j++) {
        row.add(i == 0 ? BeatMode.accent : BeatMode.normal);
      }
      beatModes.add(row);
    }
    return beatModes;
  }
}

/// Result of CSV parsing operation
class SongParseResult {
  final List<Song> successful;
  final List<String> errors;

  SongParseResult({required this.successful, required this.errors});
}

/// Result of parsing a single row
class SongParseResultItem {
  final Song? success;
  final List<String> errors;

  SongParseResultItem({this.success, this.errors = const []});
}
