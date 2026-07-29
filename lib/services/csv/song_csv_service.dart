/// Service for importing and exporting songs via CSV.
///
/// This service provides high-level methods for:
/// - Importing songs from CSV files
/// - Exporting songs to CSV files
/// - Sharing CSV files with other apps
library;

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/section.dart';
import '../../models/song.dart';
import '../../theme/mono_pulse_theme.dart';
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
      final platformFile = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (platformFile == null) {
        return SongParseResult(successful: [], errors: ['No file selected']);
      }

      final content = await _readPickedFile(platformFile);
      if (content == null) {
        return SongParseResult(
          successful: [],
          errors: ['Could not read selected CSV file'],
        );
      }

      // Parse CSV
      return _parser.parse(content);
    } catch (e, stackTrace) {
      return SongParseResult(
        successful: [],
        errors: ['Import failed: $e\n$stackTrace'],
      );
    }
  }

  /// Import songs from CSV bytes returned by a file picker or drag/drop.
  SongParseResult importFromBytes(Uint8List bytes) {
    return _parser.parse(utf8.decode(bytes, allowMalformed: true));
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
  /// Returns true if the save/download action was started successfully.
  Future<bool> exportToFile(List<Song> songs) async {
    try {
      final filePath = await FilePicker.saveFile(
        dialogTitle: 'Export FlowGroove songs',
        fileName: _createExportFileName(),
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: exportToBytes(songs),
      );

      // On web, file_picker starts a browser download and returns null.
      return kIsWeb || filePath != null;
    } catch (e, stackTrace) {
      debugPrint('Export failed: $e\n$stackTrace');
      return false;
    }
  }

  /// Export songs to CSV and share with other apps.
  ///
  /// Returns true if sharing was successful.
  Future<bool> exportAndShare(List<Song> songs) async {
    try {
      final fileName = _createExportFileName();
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              exportToBytes(songs),
              name: fileName,
              mimeType: 'text/csv',
            ),
          ],
          fileNameOverrides: [fileName],
          subject: 'FlowGroove Song Export',
          text: 'Exported ${songs.length} songs from FlowGroove',
        ),
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

  /// Export songs to UTF-8 CSV bytes.
  Uint8List exportToBytes(List<Song> songs) {
    return Uint8List.fromList(utf8.encode(exportToString(songs)));
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
      spotifyUrl: 'https://open.spotify.com/track/...',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      beatModes: [],
      sections: [
        Section(
          id: '',
          name: 'Intro',
          duration: 4,
          colorValue: MonoPulseColors.section5.withValues(alpha: 1).toARGB32(),
        ),
        Section(
          id: '',
          name: 'Verse',
          duration: 8,
          colorValue: MonoPulseColors.section8.withValues(alpha: 1).toARGB32(),
        ),
      ],
    );

    return _serializer.serialize([template]);
  }

  Future<String?> _readPickedFile(PlatformFile file) async {
    try {
      return utf8.decode(await file.readAsBytes(), allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  String _createExportFileName() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'flowgroove_export_$timestamp.csv';
  }
}
