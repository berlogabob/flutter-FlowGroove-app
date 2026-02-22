import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/api_error.dart';

/// MusicBrainz Service for searching recordings and getting metadata.
///
/// MusicBrainz is a free and open music encyclopedia that collects
/// music metadata and makes it available to the public.
///
/// All methods throw [ApiError] exceptions for proper error handling.
class MusicBrainzService {
  static const String _baseUrl = 'https://musicbrainz.org/ws/2';
  static const String _userAgent = 'RepSync/1.0.0 (berloga@example.com)';

  /// Searches for recordings on MusicBrainz.
  ///
  /// Returns a list of [MusicBrainzRecording] matching the query.
  /// Throws [ApiError] if the search fails.
  static Future<List<MusicBrainzRecording>> searchRecording(
    String query,
  ) async {
    if (query.trim().isEmpty) {
      throw ApiError.validation(message: 'Search query cannot be empty.');
    }

    try {
      // Clean query - remove special characters
      final cleanQuery = query.trim().replaceAll(RegExp(r'[^\w\s]'), ' ');

      // Try different query formats to improve results
      final queries = [
        // Try exact phrase first
        'recording:"$cleanQuery"',
        // Then try with artist: prefix
        'recording:$cleanQuery OR artist:$cleanQuery',
        // Fallback to simple query
        cleanQuery,
      ];

      for (final searchQuery in queries) {
        final encodedQuery = Uri.encodeComponent(searchQuery);
        final url =
            '$_baseUrl/recording?query=$encodedQuery&fmt=json&limit=15&inc=artist-credits+releases';

        final response = await http.get(
          Uri.parse(url),
          headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final recordings = data['recordings'] as List<dynamic>? ?? [];

          if (recordings.isNotEmpty) {
            return recordings
                .map(
                  (r) =>
                      MusicBrainzRecording.fromJson(r as Map<String, dynamic>),
                )
                .toList();
          }
        } else if (response.statusCode == 429) {
          // Rate limited - wait and retry
          await Future.delayed(const Duration(seconds: 2));
          continue;
        } else if (response.statusCode >= 500) {
          throw ApiError.network(
            message: 'MusicBrainz server is temporarily unavailable.',
            exception: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          );
        } else if (response.statusCode >= 400) {
          throw ApiError.network(
            message: 'Failed to search MusicBrainz.',
            exception: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          );
        }

        // Small delay between queries to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } on ApiError {
      rethrow;
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }

    return [];
  }
}

class MusicBrainzRecording {
  final String? title;
  final String? artist;
  final String? release;
  final int? durationMs; // in milliseconds
  final int? bpm;

  MusicBrainzRecording({
    this.title,
    this.artist,
    this.release,
    this.durationMs,
    this.bpm,
  });

  factory MusicBrainzRecording.fromJson(Map<String, dynamic> json) {
    String? artistName;
    final artistCredits = json['artist-credit'] as List<dynamic>?;
    if (artistCredits != null && artistCredits.isNotEmpty) {
      final firstArtist = artistCredits[0];
      if (firstArtist is Map) {
        final artist = firstArtist['artist'] as Map<String, dynamic>?;
        if (artist != null) {
          artistName = artist['name'] as String?;
        }
      }
    }

    String? releaseName;
    final releases = json['releases'] as List<dynamic>?;
    if (releases != null && releases.isNotEmpty) {
      final firstRelease = releases[0] as Map<String, dynamic>?;
      if (firstRelease != null) {
        releaseName = firstRelease['title'] as String?;
      }
    }

    // Get duration in milliseconds
    final duration = json['length'] as int?;

    // Calculate BPM from duration if available (assuming 4/4 time, quarter notes)
    int? calculatedBpm;
    if (duration != null && duration > 0) {
      // Common tempos are typically 60-200 BPM
      final rawBpm = 60000 / duration;
      if (rawBpm >= 40 && rawBpm <= 300) {
        calculatedBpm = rawBpm.round();
      }
    }

    return MusicBrainzRecording(
      title: json['title'] as String?,
      artist: artistName,
      release: releaseName,
      durationMs: duration,
      bpm: calculatedBpm,
    );
  }

  String get displayInfo {
    final parts = <String>[];
    if (release != null) parts.add(release!);
    if (bpm != null) parts.add('$bpm BPM');
    return parts.isEmpty ? '' : '(${parts.join(', ')})';
  }
}
