import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:http/http.dart' as http;

/// lyrics.ovh — plain lyric-text autofill.
///
/// ponytail: free, no auth. Returns plain text only (no chords, no song map —
/// those aren't available from any free API). Web-guarded (no CORS header)
/// like DeezerService; add a Functions proxy route if web needs lyrics.
class LyricsService {
  static const String _baseUrl = 'https://api.lyrics.ovh/v1';
  static const Duration _timeout = Duration(seconds: 8);

  /// HTTP client, replaceable in tests.
  @visibleForTesting
  static http.Client client = http.Client();

  /// Best-effort plain lyrics for [artist] / [title].
  ///
  /// Returns null when lyrics.ovh has no match or any error occurs — autofill
  /// must never break the form.
  static Future<String?> getLyrics({
    required String title,
    required String artist,
  }) async {
    if (kIsWeb || title.trim().isEmpty || artist.trim().isEmpty) return null;
    try {
      final response = await client
          .get(Uri.parse(
            '$_baseUrl/${Uri.encodeComponent(artist)}/${Uri.encodeComponent(title)}',
          ))
          .timeout(_timeout);
      if (response.statusCode != 200) return null;

      final lyrics = (json.decode(response.body)
          as Map<String, dynamic>)['lyrics'] as String?;
      final trimmed = lyrics?.trim();
      return (trimmed != null && trimmed.isNotEmpty) ? trimmed : null;
    } catch (_) {
      return null;
    }
  }
}
