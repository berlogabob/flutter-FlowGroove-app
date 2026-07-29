import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:http/http.dart' as http;
import '../../config/env_config.dart';

/// lyrics.ovh — plain lyric-text autofill.
///
/// ponytail: free, no auth. Returns plain text only (no chords, no song map —
/// those aren't available from any free API). No CORS header, so web routes
/// through the API_PROXY_URL CORS shim (like DeezerService); mobile calls it
/// directly. Off on web when no proxy is configured.
class LyricsService {
  static const String _baseUrl = 'https://api.lyrics.ovh/v1';
  static const Duration _timeout = Duration(seconds: 8);

  /// HTTP client, replaceable in tests.
  @visibleForTesting
  static http.Client client = http.Client();

  /// Best-effort plain lyrics for [artist] / [title].
  ///
  /// Returns null when lyrics.ovh has no match, web has no proxy, or any error
  /// occurs — autofill must never break the form.
  static Future<String?> getLyrics({
    required String title,
    required String artist,
  }) async {
    if (title.trim().isEmpty || artist.trim().isEmpty) return null;
    try {
      final target =
          '$_baseUrl/${Uri.encodeComponent(artist)}/${Uri.encodeComponent(title)}';
      Uri uri;
      if (kIsWeb) {
        final proxy = env.apiProxyUrl;
        if (proxy == null) return null;
        uri = Uri.parse(proxy).replace(queryParameters: {'url': target});
      } else {
        uri = Uri.parse(target);
      }
      final response = await client.get(uri).timeout(_timeout);
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
