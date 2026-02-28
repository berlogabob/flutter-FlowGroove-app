/// CSV serializer for song import/export.
///
/// This service handles converting Song objects into CSV format,
/// with support for all nested structures (sections, links, beat modes).
library;

import 'package:csv/csv.dart';
import 'package:flutter_repsync_app/models/song.dart';
import 'package:flutter_repsync_app/models/section.dart';
import 'package:flutter_repsync_app/models/link.dart';
import 'song_csv_schema.dart';

class SongCsvSerializer {
  /// Serialize a list of Song objects into CSV string.
  ///
  /// Returns CSV content as string.
  String serialize(List<Song> songs) {
    final csvRows = <List<String>>[];

    // Add headers
    final headers = SongCsvSchema.getAllHeaders();
    csvRows.add(headers);

    // Add rows for each song
    for (final song in songs) {
      final row = _serializeSong(song, headers);
      csvRows.add(row);
    }

    // Use csv.encode() from package:csv/csv.dart
    // Add UTF-8 BOM for Excel compatibility
    return '\uFEFF${csv.encode(csvRows)}';
  }

  /// Serialize a single Song object into a CSV row.
  List<String> _serializeSong(Song song, List<String> headers) {
    final row = <String>[];

    // Map header to value
    for (final header in headers) {
      final value = _getValueForHeader(song, header);
      row.add(value ?? '');
    }

    return row;
  }

  /// Get value for a specific header from a Song object.
  String? _getValueForHeader(Song song, String header) {
    // Core fields
    switch (header) {
      case SongCsvSchema.title:
        return song.title;
      case SongCsvSchema.artist:
        return song.artist;

      // Split key components (NEW FORMAT)
      case SongCsvSchema.originalKeyBase:
        if (song.originalKey == null || song.originalKey!.isEmpty) return null;
        final components = SongCsvSchema.parseKeyString(song.originalKey);
        return components['base'];
      case SongCsvSchema.originalKeyAccidental:
        if (song.originalKey == null || song.originalKey!.isEmpty) return null;
        final components = SongCsvSchema.parseKeyString(song.originalKey);
        return components['accidental'];
      case SongCsvSchema.originalKeyScale:
        if (song.originalKey == null || song.originalKey!.isEmpty) return null;
        final components = SongCsvSchema.parseKeyString(song.originalKey);
        return components['scale'];

      case SongCsvSchema.ourKeyBase:
        if (song.ourKey == null || song.ourKey!.isEmpty) return null;
        final components = SongCsvSchema.parseKeyString(song.ourKey);
        return components['base'];
      case SongCsvSchema.ourKeyAccidental:
        if (song.ourKey == null || song.ourKey!.isEmpty) return null;
        final components = SongCsvSchema.parseKeyString(song.ourKey);
        return components['accidental'];
      case SongCsvSchema.ourKeyScale:
        if (song.ourKey == null || song.ourKey!.isEmpty) return null;
        final components = SongCsvSchema.parseKeyString(song.ourKey);
        return components['scale'];

      // Legacy single-field keys (for backward compatibility)
      case SongCsvSchema.originalKey:
        return song.originalKey;
      case SongCsvSchema.ourKey:
        return song.ourKey;

      case SongCsvSchema.originalBPM:
        return song.originalBPM?.toString();
      case SongCsvSchema.ourBPM:
        return song.ourBPM?.toString();
      case SongCsvSchema.spotifyUrl:
        return song.spotifyUrl;
      case SongCsvSchema.notes:
        return song.notes;
      case SongCsvSchema.bandId:
        return song.bandId;
      case SongCsvSchema.accentBeats:
        return song.accentBeats.toString();
      case SongCsvSchema.regularBeats:
        return song.regularBeats.toString();

      case SongCsvSchema.metronomePattern:
        // Encode beat modes to compact format
        if (song.beatModes.isEmpty) return '';
        // Convert BeatMode enum to int (0=normal, 1=accent, 2=silent)
        final beatModesAsInt = song.beatModes
            .map(
              (row) => row.map((mode) {
                switch (mode.name) {
                  case 'accent':
                    return 1;
                  case 'silent':
                    return 2;
                  default:
                    return 0; // normal
                }
              }).toList(),
            )
            .toList();
        return SongCsvSchema.encodeBeatModes(
          beatModesAsInt,
          song.accentBeats,
          song.regularBeats,
        );

      case SongCsvSchema.tags:
        return song.tags.join(',');

      // Section headers: section_{n}_{field}
      default:
        final sectionMatch = RegExp(
          r'^section_(\d+)_(\w+)$',
        ).firstMatch(header);
        if (sectionMatch != null) {
          final sectionNum = int.tryParse(sectionMatch.group(1)!) ?? 0;
          final field = sectionMatch.group(2)!;

          if (sectionNum > 0 && sectionNum <= song.sections.length) {
            final section = song.sections[sectionNum - 1];
            return _getSectionFieldValue(section, field);
          }
          return null;
        }

        // Link headers: link_{n}_{field}
        final linkMatch = RegExp(r'^link_(\d+)_(\w+)$').firstMatch(header);
        if (linkMatch != null) {
          final linkNum = int.tryParse(linkMatch.group(1)!) ?? 0;
          final field = linkMatch.group(2)!;

          if (linkNum > 0 && linkNum <= song.links.length) {
            final link = song.links[linkNum - 1];
            return _getLinkFieldValue(link, field);
          }
          return null;
        }

        // Beat mode headers: beatMode_{row}_{col}
        final beatModeMatch = RegExp(
          r'^beatMode_(\d+)_(\d+)$',
        ).firstMatch(header);
        if (beatModeMatch != null) {
          final row = int.tryParse(beatModeMatch.group(1)!) ?? 0;
          final col = int.tryParse(beatModeMatch.group(2)!) ?? 0;

          if (row < song.beatModes.length && col < song.beatModes[row].length) {
            return song.beatModes[row][col].name;
          }
          return null;
        }

        // Unknown header
        return null;
    }
  }

  /// Get field value from a Section object
  String? _getSectionFieldValue(Section section, String field) {
    switch (field) {
      case 'name':
        return section.name;
      case 'notes':
        return section.notes;
      case 'duration':
        return section.duration.toString();
      case 'color':
        if (section.colorValue == null) return null;
        // Convert int color to hex string (AARRGGBB format)
        return section.colorValue!
            .toRadixString(16)
            .toUpperCase()
            .padLeft(8, '0');
      default:
        return null;
    }
  }

  /// Get field value from a Link object
  String? _getLinkFieldValue(Link link, String field) {
    switch (field) {
      case 'url':
        return link.url;
      case 'title':
        return link.title;
      case 'type':
        return link.type;
      default:
        return null;
    }
  }
}
