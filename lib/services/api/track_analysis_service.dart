import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Track Analysis API - Free alternative to Spotify for BPM and key
///
/// This API provides BPM, key, and mode for songs without requiring Premium.
/// Get API key from: https://rapidapi.com/soundnet-soundnet-default/api/track-analysis
/// Free tier: 100 requests/month
///
/// Configuration:
/// 1. Add TRACK_ANALYSIS_API_KEY to your .env file
/// 2. Get your key from: https://rapidapi.com/soundnet-soundnet-default/api/track-analysis
class TrackAnalysisService {
  /// Get Track Analysis API key from environment variables
  /// Falls back to 'demo' key for development if not configured
  static String get _apiKey {
    final key = dotenv.env['TRACK_ANALYSIS_API_KEY'];
    if (key == null || key.isEmpty || key == 'your_rapidapi_key_here') {
      debugPrint('⚠️ WARNING: TRACK_ANALYSIS_API_KEY not set in .env');
      debugPrint(
        '⚠️ Get your free API key from: https://rapidapi.com/soundnet-soundnet-default/api/track-analysis',
      );
      debugPrint('⚠️ Free tier: 100 requests/month');
      return 'demo'; // Fallback for development
    }
    return key;
  }

  static const String _baseUrl = 'https://track-analyses.p.rapidapi.com';

  /// Check if API is configured with a real key (not demo or placeholder)
  static bool get isConfigured {
    final key = _apiKey;
    return key != 'demo' && key != 'YOUR_RAPIDAPI_KEY' && key.isNotEmpty;
  }

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
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['result'] != null) {
          return TrackAnalysis.fromJson(data['result'] as Map<String, dynamic>);
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
