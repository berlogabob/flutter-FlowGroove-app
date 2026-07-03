import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:http/http.dart' as http;
import '../matching/fuzzy_matcher.dart';

/// Deezer public API — the BPM autofill source (#76).
///
/// No auth needed. Spotify's audio-features endpoint is closed to apps
/// created after Nov 2024, so Deezer is where BPM comes from now: search
/// the track, then read `bpm` off the full track object.
///
/// ponytail: api.deezer.com sends no Access-Control-Allow-Origin, so web is
/// skipped; add a Functions proxy route if web needs BPM autofill.
class DeezerService {
  static const String _baseUrl = 'https://api.deezer.com';
  static const Duration _timeout = Duration(seconds: 8);

  /// HTTP client, replaceable in tests.
  @visibleForTesting
  static http.Client client = http.Client();

  /// Best-effort BPM lookup for [title] / [artist].
  ///
  /// Returns null when Deezer has no confident match, no BPM for the track,
  /// or any error occurs — autofill must never break the form.
  static Future<int?> getBpm({
    required String title,
    required String artist,
  }) async {
    if (kIsWeb || title.trim().isEmpty) return null;
    try {
      final query = [title, artist].where((s) => s.trim().isNotEmpty).join(' ');
      final searchResponse = await client
          .get(
            Uri.parse(
              '$_baseUrl/search?q=${Uri.encodeComponent(query)}&limit=5',
            ),
          )
          .timeout(_timeout);
      if (searchResponse.statusCode != 200) return null;

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
      final trackResponse = await client
          .get(Uri.parse('$_baseUrl/track/$trackId'))
          .timeout(_timeout);
      if (trackResponse.statusCode != 200) return null;

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
