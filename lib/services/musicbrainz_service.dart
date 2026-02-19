import 'dart:convert';
import 'package:http/http.dart' as http;

class MusicBrainzService {
  static const String _baseUrl = 'https://musicbrainz.org/ws/2';
  static const String _userAgent = 'RepSync/1.0.0 (berloga@example.com)';

  static Future<List<MusicBrainzRecording>> searchRecording(
    String query,
  ) async {
    if (query.trim().isEmpty) return [];

    try {
      final encodedQuery = Uri.encodeComponent(query);
      // Request more data including releases for better metadata
      final url =
          '$_baseUrl/recording?query=$encodedQuery&fmt=json&limit=10&inc=artist-credits+releases';

      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final recordings = data['recordings'] as List<dynamic>? ?? [];

        return recordings
            .map(
              (r) => MusicBrainzRecording.fromJson(r as Map<String, dynamic>),
            )
            .toList();
      }
    } catch (e) {
      // Return empty list on error
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
