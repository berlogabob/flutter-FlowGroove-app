/// Beat mode validation utilities
///
/// Provides validation for 2D beat mode grids to ensure data integrity
/// and prevent corrupted state.

import '../../models/beat_mode.dart';

/// Validates a 2D beat mode grid
///
/// Throws [AssertionError] if validation fails.
/// Only active in debug mode (assertions enabled).
void validateBeatModesGrid({
  required List<List<BeatMode>> beatModes,
  required int accentBeats,
  required int regularBeats,
}) {
  assert(
    beatModes.length == accentBeats,
    'beatModes rows (${beatModes.length}) must match accentBeats ($accentBeats)',
  );

  for (int i = 0; i < beatModes.length; i++) {
    assert(
      beatModes[i].length == regularBeats,
      'beatModes[$i] columns (${beatModes[i].length}) must match regularBeats ($regularBeats)',
    );

    for (int j = 0; j < beatModes[i].length; j++) {
      assert(
        beatModes[i][j] != null,
        'beatModes[$i][$j] cannot be null',
      );
      assert(
        BeatMode.values.contains(beatModes[i][j]),
        'beatModes[$i][$j] contains invalid BeatMode: ${beatModes[i][j]}',
      );
    }
  }
}

/// Expands or contracts beat mode grid to match new dimensions
///
/// Preserves existing values where possible.
/// New cells are filled with [defaultMode] (default: BeatMode.normal).
List<List<BeatMode>> resizeBeatModesGrid({
  required List<List<BeatMode>> oldGrid,
  required int newAccentBeats,
  required int newRegularBeats,
  BeatMode defaultMode = BeatMode.normal,
}) {
  final newGrid = <List<BeatMode>>[];

  for (int i = 0; i < newAccentBeats; i++) {
    final row = <BeatMode>[];

    for (int j = 0; j < newRegularBeats; j++) {
      if (i < oldGrid.length && j < oldGrid[i].length) {
        // Preserve existing value
        row.add(oldGrid[i][j]);
      } else {
        // New cell - use default
        row.add(defaultMode);
      }
    }

    newGrid.add(row);
  }

  return newGrid;
}

/// Converts legacy 1D accent pattern to 2D beat mode grid
///
/// For backward compatibility with old state format.
List<List<BeatMode>> convertAccentPatternToBeatModes({
  required List<bool> accentPattern,
  required int regularBeats,
}) {
  return accentPattern.map((isAccent) {
    return List.generate(regularBeats, (subIndex) {
      // First subdivision gets accent mode, rest are normal
      return subIndex == 0 && isAccent
          ? BeatMode.accent
          : BeatMode.normal;
    });
  }).toList();
}

/// Serializes 2D beat mode grid to JSON map
///
/// Uses sparse format: {"0-0": "accent", "0-1": "normal", ...}
Map<String, String> beatModesToJson(List<List<BeatMode>> beatModes) {
  final result = <String, String>{};

  for (int i = 0; i < beatModes.length; i++) {
    for (int j = 0; j < beatModes[i].length; j++) {
      result['$i-$j'] = beatModes[i][j].name;
    }
  }

  return result;
}

/// Deserializes JSON map to 2D beat mode grid
///
/// Supports both sparse map format and legacy list format.
List<List<BeatMode>> beatModesFromJson(
  dynamic json, {
  required int accentBeats,
  required int regularBeats,
  BeatMode defaultMode = BeatMode.normal,
}) {
  // Initialize grid with default mode
  final grid = List.generate(
    accentBeats,
    (i) => List.filled(regularBeats, defaultMode),
  );

  if (json == null) return grid;

  // Support map format: {"0-0": "accent", ...}
  if (json is Map<String, dynamic>) {
    for (final entry in json.entries) {
      final parts = entry.key.split('-');
      if (parts.length == 2) {
        final i = int.tryParse(parts[0]);
        final j = int.tryParse(parts[1]);

        if (i != null && j != null && i < accentBeats && j < regularBeats) {
          final mode = BeatMode.values.firstWhere(
            (m) => m.name == (entry.value as String),
            orElse: () => defaultMode,
          );
          grid[i][j] = mode;
        }
      }
    }
  }
  // Support legacy list format: [["accent", "normal"], ...]
  else if (json is List) {
    for (int i = 0; i < json.length && i < accentBeats; i++) {
      if (json[i] is List) {
        for (int j = 0; j < (json[i] as List).length && j < regularBeats; j++) {
          final mode = BeatMode.values.firstWhere(
            (m) => m.name == ((json[i] as List)[j] as String),
            orElse: () => defaultMode,
          );
          grid[i][j] = mode;
        }
      }
    }
  }

  return grid;
}
