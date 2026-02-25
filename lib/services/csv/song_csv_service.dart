/// Service for importing and exporting songs via CSV.
///
/// This service provides high-level methods for:
/// - Importing songs from CSV files
/// - Exporting songs to CSV files
/// - Sharing CSV files with other apps
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/song.dart';
import '../../models/section.dart';
import 'song_csv_parser.dart';
import 'song_csv_serializer.dart';

/// Service for CSV import/export operations
class SongCsvService {
  final SongCsvParser _parser = SongCsvParser();
  final SongCsvSerializer _serializer = SongCsvSerializer();

  /// Import songs from a CSV file.
  ///
  /// Returns [SongParseResult] with successful songs and any errors.
  Future<SongParseResult> importFromFile() async {
    try {
      // Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return SongParseResult(successful: [], errors: ['No file selected']);
      }

      final filePath = result.files.single.path;
      if (filePath == null) {
        return SongParseResult(successful: [], errors: ['Could not get file path']);
      }

      // Read file content
      final file = File(filePath);
      final content = await file.readAsString(encoding: utf8);

      // Parse CSV
      return _parser.parse(content);
    } catch (e, stackTrace) {
      return SongParseResult(
        successful: [],
        errors: ['Import failed: $e\n$stackTrace'],
      );
    }
  }

  /// Import songs from CSV string (e.g., copy-paste from Google Sheets).
  Future<SongParseResult> importFromString(String csvContent) async {
    try {
      return _parser.parse(csvContent);
    } catch (e, stackTrace) {
      return SongParseResult(
        successful: [],
        errors: ['Import failed: $e\n$stackTrace'],
      );
    }
  }

  /// Export songs to a CSV file and save to device.
  ///
  /// Returns the file path if successful, null otherwise.
  Future<String?> exportToFile(List<Song> songs) async {
    try {
      // Serialize to CSV
      final csvContent = _serializer.serialize(songs);

      // Get directory
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/repsync_export_$timestamp.csv';

      // Write file with UTF-8 BOM for Excel compatibility
      final file = File(filePath);
      await file.writeAsString(
        '\ufeff$csvContent', // UTF-8 BOM
        encoding: utf8,
      );

      return filePath;
    } catch (e, stackTrace) {
      debugPrint('Export failed: $e\n$stackTrace');
      return null;
    }
  }

  /// Export songs to CSV and share with other apps.
  ///
  /// Returns true if sharing was successful.
  Future<bool> exportAndShare(List<Song> songs) async {
    try {
      // Export to file
      final filePath = await exportToFile(songs);
      if (filePath == null) {
        return false;
      }

      // Share file
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'RepSync Song Export',
        text: 'Exported ${songs.length} songs from RepSync',
      );

      return true;
    } catch (e, stackTrace) {
      debugPrint('Share failed: $e\n$stackTrace');
      return false;
    }
  }

  /// Export songs to CSV string.
  String exportToString(List<Song> songs) {
    return _serializer.serialize(songs);
  }

  /// Create a sample CSV template for users to fill in.
  String createTemplate() {
    final template = Song(
      id: '',
      title: 'Example Song Title',
      artist: 'Example Artist',
      originalKey: 'C',
      originalBPM: 120,
      ourKey: 'D',
      ourBPM: 130,
      links: [],
      notes: 'Song notes here',
      tags: ['rock', 'live'],
      bandId: null,
      spotifyUrl: 'https://open.spotify.com/track/...',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      accentBeats: 4,
      regularBeats: 1,
      beatModes: [],
      sections: [
        Section(
          id: '',
          name: 'Intro',
          notes: '',
          duration: 4,
          colorValue: Colors.blue.toARGB32(),
        ),
        Section(
          id: '',
          name: 'Verse',
          notes: '',
          duration: 8,
          colorValue: Colors.green.toARGB32(),
        ),
      ],
    );

    return _serializer.serialize([template]);
  }
}
