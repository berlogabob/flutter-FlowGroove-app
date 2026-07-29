import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:http/http.dart' as http;
import '../../config/env_config.dart';
import '../matching/fuzzy_matcher.dart';

/// Deezer public API — song search + BPM autofill (#76).
///
/// No auth needed. Spotify's audio-features endpoint is closed to apps
/// created after Nov 2024, so Deezer is the search/BPM source now.
///
/// api.deezer.com sends no Access-Control-Allow-Origin, so on web every call
/// is routed through the API_PROXY_URL CORS shim (Functions). Mobile calls it
/// directly. When neither is available (web, no proxy), calls no-op.
class DeezerService {
  static const String _baseUrl = 'https://api.deezer.com';
  static const Duration _timeout = Duration(seconds: 8);

  /// HTTP client, replaceable in tests.
  @visibleForTesting
  static http.Client client = http.Client();

  /// GET [targetUrl], directly on mobile or via the CORS proxy on web.
  /// Returns null on web when no proxy is configured (feature simply off).
  static Future<http.Response?> _get(String targetUrl) async {
    Uri uri;
    if (kIsWeb) {
      final proxy = env.apiProxyUrl;
      if (proxy == null) return null;
      uri = Uri.parse(proxy).replace(queryParameters: {'url': targetUrl});
    } else {
      uri = Uri.parse(targetUrl);
    }
    return client.get(uri).timeout(_timeout);
  }

  /// Search Deezer for tracks matching [title] / [artist].
  ///
  /// Returns [] on any error or when web has no proxy — autofill must never
  /// break the form.
  static Future<List<DeezerTrack>> search({
    required String title,
    required String artist,
  }) async {
    if (title.trim().isEmpty && artist.trim().isEmpty) return [];
    try {
      final query = [title, artist].where((s) => s.trim().isNotEmpty).join(' ');
      final response = await _get(
        '$_baseUrl/search?q=${Uri.encodeComponent(query)}&limit=10',
      );
      if (response == null || response.statusCode != 200) return [];

      final results =
          (json.decode(response.body) as Map<String, dynamic>)['data']
                  as List<dynamic>? ??
              [];
      return results
          .map((e) => DeezerTrack.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Best-effort BPM lookup for [title] / [artist].
  ///
  /// Returns null when Deezer has no confident match, no BPM for the track,
  /// web has no proxy, or any error occurs — autofill must never break the form.
  static Future<int?> getBpm({
    required String title,
    required String artist,
  }) async {
    if (title.trim().isEmpty) return null;
    try {
      final query = [title, artist].where((s) => s.trim().isNotEmpty).join(' ');
      final searchResponse = await _get(
        '$_baseUrl/search?q=${Uri.encodeComponent(query)}&limit=5',
      );
      if (searchResponse == null || searchResponse.statusCode != 200) {
        return null;
      }

      final results =
          (json.decode(searchResponse.body)
                  as Map<String, dynamic>)['data'] as List<dynamic>? ??
              [];

      // Sanity-check the hit against what the user selected — never fill a
      // BPM from an unrelated track.
      int? trackId;
      for (final item in results) {
        final track = item as Map<String, dynamic>;
        final match = FuzzyMatcher.calculateMatchScore(
          inputTitle: title,
          inputArtist: artist,
          targetTitle: track['title'] as String? ?? '',
          targetArtist:
              (track['artist'] as Map<String, dynamic>?)?['name'] as String? ??
                  '',
        );
        if (match.overall >= 0.6) {
          trackId = (track['id'] as num?)?.toInt();
          break;
        }
      }
      if (trackId == null) return null;

      // Search results carry no bpm — only the full track object does.
      final trackResponse = await _get('$_baseUrl/track/$trackId');
      if (trackResponse == null || trackResponse.statusCode != 200) return null;

      final bpm =
          ((json.decode(trackResponse.body) as Map<String, dynamic>)['bpm']
                  as num?)
              ?.round();
      return (bpm != null && bpm > 0) ? bpm : null;
    } catch (_) {
      return null;
    }
  }
}

/// Minimal Deezer track shape for autofill suggestions.
class DeezerTrack {
  DeezerTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.durationMs,
  });

  factory DeezerTrack.fromJson(Map<String, dynamic> json) {
    // Deezer `duration` is in whole seconds.
    final durationSec = (json['duration'] as num?)?.toInt();
    return DeezerTrack(
      id: (json['id'] as num?)?.toInt().toString() ?? '',
      title: json['title'] as String? ?? '',
      artist:
          (json['artist'] as Map<String, dynamic>?)?['name'] as String? ??
              'Unknown',
      album: (json['album'] as Map<String, dynamic>?)?['title'] as String?,
      durationMs: durationSec != null ? durationSec * 1000 : null,
    );
  }

  final String id;
  final String title;
  final String artist;
  final String? album;
  final int? durationMs;
}
