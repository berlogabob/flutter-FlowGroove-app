import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/musicbrainz_error.dart';
import '../models/musicbrainz_recording.dart';

/// MusicBrainz API Service
///
/// Provides access to MusicBrainz database for song metadata.
///
/// IMPORTANT: MusicBrainz has strict rate limits:
/// - 1 request per second
/// - Must provide User-Agent header
/// - Excessive requests will result in temporary bans
///
/// See: https://musicbrainz.org/doc/Development/XML_Web_Service/Rate_Limiting
class MusicBrainzService {
  MusicBrainzService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _baseUrl = 'https://musicbrainz.org/ws/2';
  static const String _userAgent = 'FlowGroove/1.0 (berloga.bob@gmail.com)';
  static const Map<String, String> _headers = {
    'User-Agent': _userAgent,
    'Accept': 'application/json',
  };

  /// Rate limiting: minimum time between requests (1 second)
  static const Duration _rateLimitDelay = Duration(milliseconds: 1000);

  static const Duration _timeout = Duration(seconds: 10);

  DateTime? _lastRequestTime;

  /// Search recordings by title and artist
  ///
  /// [title] - Song title to search for
  /// [artist] - Artist name (optional, improves accuracy)
  /// [limit] - Maximum results to return (default: 10, max: 100)
  /// [offset] - Result offset for pagination
  ///
  /// Returns a list of [MusicBrainzRecording] matching the query.
  Future<List<MusicBrainzRecording>> searchRecording({
    required String title,
    String? artist,
    int limit = 10,
    int offset = 0,
  }) async {
    // Autocomplete sends partial titles ("hit the li"), so a quoted phrase
    // query matches nothing. AND all tokens and wildcard the last one so
    // mid-word typing still finds "Hit the Lights" (#75/#78).
    final tokens = title
        .trim()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return [];
    final terms = [
      ...tokens.take(tokens.length - 1),
      '${tokens.last}*',
    ];

    final String query;
    if (artist != null && artist.isNotEmpty) {
      query = 'recording:(${terms.join(' AND ')}) AND artist:"$artist"';
    } else {
      // Bare queries often end with the artist ("ride the lightning
      // metallica"). Let each token match the title OR the artist, otherwise
      // the original recording (artist token absent from its title) is never
      // returned — only covers whose title/alias mentions the artist (#87).
      query = terms.map((t) => '(recording:$t OR artist:$t)').join(' AND ');
    }

    return _search(
      query: query,
      limit: limit,
      offset: offset,
      inc: ['artists', 'releases', 'isrcs', 'aliases'],
    );
  }

  /// Free-form search that tries progressively looser query shapes until one
  /// returns results (exact recording phrase, recording-or-artist, plain).
  ///
  /// Used by the manual MusicBrainz search sheet. Returns an empty list when
  /// nothing matches; waits and moves on when rate-limited mid-cascade.
  Future<List<MusicBrainzRecording>> searchFlexible(
    String query, {
    int limit = 15,
  }) async {
    final clean = query.trim().replaceAll(RegExp(r'[^\w\s]'), ' ').trim();
    if (clean.isEmpty) return [];

    final queries = [
      'recording:"$clean"',
      'recording:$clean OR artist:$clean',
      clean,
    ];

    for (final searchQuery in queries) {
      try {
        final results = await _search(
          query: searchQuery,
          limit: limit,
          inc: ['artists', 'releases'],
        );
        if (results.isNotEmpty) return results;
      } on RateLimitError catch (e) {
        await Future<void>.delayed(e.retryAfter ?? const Duration(seconds: 2));
      }
    }
    return [];
  }

  /// Internal search implementation
  Future<List<MusicBrainzRecording>> _search({
    required String query,
    required int limit,
    int offset = 0,
    List<String>? inc,
  }) async {
    final uri = Uri.parse('$_baseUrl/recording').replace(
      queryParameters: {
        'query': query,
        'fmt': 'json',
        'limit': limit.toString(),
        'offset': offset.toString(),
        'inc': inc?.join('+') ?? '',
      },
    );

    final data = await _getJson(uri);
    final recordings = data['recordings'] as List<dynamic>? ?? [];

    return recordings
        .map((r) => MusicBrainzRecording.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Perform a rate-limited GET and map HTTP failures to [MusicBrainzError]s.
  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    await _enforceRateLimit();

    http.Response response;
    try {
      response = await _client.get(uri, headers: _headers).timeout(_timeout);
    } on MusicBrainzError {
      rethrow;
    } catch (e) {
      throw NetworkError(originalError: e);
    }

    final statusCode = response.statusCode;
    if (statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    if (statusCode == 429) {
      final retryAfter = response.headers['retry-after'];
      throw RateLimitError(
        retryAfter: Duration(seconds: int.tryParse(retryAfter ?? '') ?? 1),
      );
    }
    if (statusCode == 404) throw const NotFoundError();
    if (statusCode == 401 || statusCode == 403) throw const AuthError();
    if (statusCode >= 500) throw ServerError(statusCode: statusCode);
    throw MusicBrainzGenericError(
      message: 'MusicBrainz API error',
      details: 'HTTP $statusCode: ${response.reasonPhrase}',
    );
  }

  /// Enforce rate limiting (1 request per second)
  Future<void> _enforceRateLimit() async {
    final now = DateTime.now();

    if (_lastRequestTime != null) {
      final elapsed = now.difference(_lastRequestTime!);

      if (elapsed < _rateLimitDelay) {
        final delay = _rateLimitDelay - elapsed;
        debugPrint('MusicBrainz rate limit: waiting ${delay.inMilliseconds}ms');
        await Future<void>.delayed(delay);
      }
    }

    _lastRequestTime = DateTime.now();
  }

  /// Reset rate limit tracking (for testing)
  @visibleForTesting
  void resetRateLimit() {
    _lastRequestTime = null;
  }
}
