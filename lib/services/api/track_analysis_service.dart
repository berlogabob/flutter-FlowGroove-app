import 'package:flutter/foundation.dart' show debugPrint;

/// Client-side RapidAPI track analysis is intentionally disabled.
///
/// Privileged third-party keys must not be used from the client. Until a
/// backend proxy exists for this integration, the feature is kept as a
/// no-op and the UI should guide users to Spotify-backed analysis instead.
class TrackAnalysisService {
  static bool get isConfigured => false;

  /// Search for track and get BPM/key.
  ///
  /// Returns `null` until this flow is reintroduced behind a backend proxy.
  static Future<TrackAnalysis?> analyzeTrack(
    String title,
    String artist,
  ) async {
    if (title.trim().isEmpty) return null;
    debugPrint(
      'TrackAnalysisService is disabled on the client. '
      'Use backend analysis or Spotify proxy-backed flows instead.',
    );
    return null;
  }
}

class TrackAnalysis {

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
  final String? title;
  final String? artist;
  final String? key;
  final String? mode; // major/minor
  final int? bpm;
  final double? energy;
  final double? danceability;

  String get musicalKey {
    if (key == null) return '';
    if (mode != null) {
      return '$key $mode';
    }
    return key!;
  }
}
