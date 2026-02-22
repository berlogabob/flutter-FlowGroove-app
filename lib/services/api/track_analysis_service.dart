import 'dart:convert';
import 'package:http/http.dart' as http;

/// Track Analysis API - Free alternative to Spotify for BPM and key
///
/// This API provides BPM, key, and mode for songs without requiring Premium.
/// Get API key from: https://rapidapi.com/soundnet-soundnet-default/api/track-analysis
class TrackAnalysisService {
  // TODO: Replace with your RapidAPI key from https://rapidapi.com/soundnet-soundnet-default/api/track-analysis
  // For now, using a demo key - replace with your own for production
  static const String _apiKey = 'demo';
  static const String _baseUrl = 'https://track-analyses.p.rapidapi.com';

  /// Check if API is configured
  static bool get isConfigured => _apiKey != 'YOUR_RAPIDAPI_KEY';

  /// Search for track and get BPM/key
  static Future<TrackAnalysis?> analyzeTrack(
    String title,
    String artist,
  ) async {
    if (!isConfigured) return null;
    if (title.trim().isEmpty) return null;

    try {
      final query = '$title $artist'.trim();

      final response = await http.get(
        Uri.parse('$_baseUrl/track-analysis?track=$query'),
        headers: {
          'X-RapidAPI-Key': _apiKey,
          'X-RapidAPI-Host': 'track-analysis.p.rapidapi.com',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['result'] != null) {
          return TrackAnalysis.fromJson(data['result']);
        }
      }
    } catch (e) {
      // API error
    }
    return null;
  }
}

class TrackAnalysis {
  final String? title;
  final String? artist;
  final String? key;
  final String? mode; // major/minor
  final int? bpm;
  final double? energy;
  final double? danceability;

  TrackAnalysis({
    this.title,
    this.artist,
    this.key,
    this.mode,
    this.bpm,
    this.energy,
    this.danceability,
  });

  factory TrackAnalysis.fromJson(Map<String, dynamic> json) {
    return TrackAnalysis(
      title: json['track'] as String?,
      artist: json['artist'] as String?,
      key: json['key'] as String?,
      mode: json['mode'] as String?,
      bpm: json['bpm'] as int?,
      energy: (json['energy'] as num?)?.toDouble(),
      danceability: (json['danceability'] as num?)?.toDouble(),
    );
  }

  String get musicalKey {
    if (key == null) return '';
    if (mode != null) {
      return '$key $mode';
    }
    return key!;
  }
}
