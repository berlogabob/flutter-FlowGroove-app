import 'dart:convert';
import 'package:dio/dio.dart';
import '../../config/env_config.dart';
import '../../models/api_error.dart';
import 'web_config.stub.dart' if (dart.library.html) 'web_config.web.dart';

/// Spotify Service for searching songs and getting audio features (BPM, key).
///
/// To enable Spotify:
/// 1. Go to https://developer.spotify.com/dashboard
/// 2. Create an app to get Client ID and Client Secret
/// 3. Add credentials to .env file (SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET)
///    OR for web: set window.env in web/config.js
///
/// SECURITY: Credentials are loaded securely via EnvConfig
/// - Mobile: From .env file (must be in .gitignore)
/// - Web: From window.env (injected at runtime via config.js)
/// - NEVER commit credentials to git!
///
/// All methods throw [ApiError] exceptions for proper error handling.
class SpotifyService {
  /// Get Spotify Client ID from environment variables
  /// Uses secure EnvConfig for all platforms
  static String get _clientId => env.spotifyClientId;

  /// Get Spotify Client Secret from environment variables
  /// Uses secure EnvConfig for all platforms
  static String get _clientSecret => env.spotifyClientSecret;

  static const String _baseUrl = 'https://api.spotify.com/v1';

  /// Check if Spotify API is configured
  static bool get isConfigured => env.isSpotifyConfigured;

  static String? _accessToken;
  static DateTime? _tokenExpiry;
  static final Dio _dio = Dio();

  static Future<bool> _authenticate() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return true;
    }

    try {
      final credentials = base64Encode(
        utf8.encode('$_clientId:$_clientSecret'),
      );

      final response = await _dio.post(
        'https://accounts.spotify.com/api/token',
        options: Options(
          headers: {
            'Authorization': 'Basic $credentials',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
        data: 'grant_type=client_credentials',
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        _accessToken = data['access_token'] as String;
        final expiresIn = data['expires_in'] as int;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
        return true;
      } else if (response.statusCode == 401) {
        throw ApiError.auth(
          message: 'Invalid Spotify credentials. Please check your API keys.',
          exception: 'HTTP ${response.statusCode}',
        );
      } else {
        throw ApiError.network(
          message: 'Failed to authenticate with Spotify.',
          exception: 'HTTP ${response.statusCode}',
        );
      }
    } on ApiError {
      rethrow;
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  /// Searches for tracks on Spotify.
  ///
  /// Returns a list of [SpotifyTrack] matching the query.
  /// Throws [ApiError] if the search fails.
  static Future<List<SpotifyTrack>> search(String query) async {
    if (!await _authenticate()) {
      throw ApiError.auth(
        message:
            'Spotify authentication failed. Please check your credentials.',
      );
    }

    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = '$_baseUrl/search?q=$encodedQuery&type=track&limit=10';

      final response = await _dio.get(
        url,
        options: Options(
          headers: {'Authorization': 'Bearer $_accessToken'},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final tracks = data['tracks']['items'] as List<dynamic>? ?? [];
        return tracks
            .map((t) => SpotifyTrack.fromJson(t as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 401) {
        // Token expired, try to re-authenticate
        _accessToken = null;
        _tokenExpiry = null;
        if (await _authenticate()) {
          return search(query); // Retry with new token
        }
        throw ApiError.auth(
          message: 'Spotify authentication expired. Please try again.',
          exception: 'HTTP ${response.statusCode}',
        );
      } else if (response.statusCode == 403) {
        throw ApiError.permission(
          message: 'Spotify Premium required for API access.',
          exception: 'HTTP ${response.statusCode}',
        );
      } else if (response.statusCode == 429) {
        throw ApiError.network(
          message: 'Spotify rate limit exceeded. Please try again later.',
          exception: 'HTTP ${response.statusCode}: Rate limited',
        );
      } else {
        throw ApiError.network(
          message: 'Failed to search Spotify.',
          exception: 'HTTP ${response.statusCode}',
        );
      }
    } on ApiError {
      rethrow;
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  /// Gets audio features for a track.
  ///
  /// Returns [SpotifyAudioFeatures] for the given track ID.
  /// Returns `null` if features are not available.
  /// Throws [ApiError] if the request fails.
  static Future<SpotifyAudioFeatures?> getAudioFeatures(String trackId) async {
    if (!await _authenticate()) {
      throw ApiError.auth(
        message:
            'Spotify authentication failed. Please check your credentials.',
      );
    }

    try {
      final url = '$_baseUrl/audio-features/$trackId';
      final response = await _dio.get(
        url,
        options: Options(
          headers: {'Authorization': 'Bearer $_accessToken'},
        ),
      );

      if (response.statusCode == 200) {
        return SpotifyAudioFeatures.fromJson(
          response.data as Map<String, dynamic>,
        );
      } else if (response.statusCode == 401) {
        // Token expired, try to re-authenticate
        _accessToken = null;
        _tokenExpiry = null;
        if (await _authenticate()) {
          return getAudioFeatures(trackId); // Retry with new token
        }
        throw ApiError.auth(
          message: 'Spotify authentication expired. Please try again.',
          exception: 'HTTP ${response.statusCode}',
        );
      } else if (response.statusCode == 404) {
        // Audio features not available for this track
        return null;
      } else {
        throw ApiError.network(
          message: 'Failed to get audio features from Spotify.',
          exception: 'HTTP ${response.statusCode}',
        );
      }
    } on ApiError {
      rethrow;
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }
}

class SpotifyTrack {
  final String id;
  final String name;
  final String artist;
  final String? album;
  final String? albumArt;
  final int? durationMs;
  final String? spotifyUrl;

  SpotifyTrack({
    required this.id,
    required this.name,
    required this.artist,
    this.album,
    this.albumArt,
    this.durationMs,
    this.spotifyUrl,
  });

  factory SpotifyTrack.fromJson(Map<String, dynamic> json) {
    String? albumArt;
    final album = json['album'] as Map<String, dynamic>?;
    if (album != null) {
      final images = album['images'] as List<dynamic>?;
      if (images != null && images.isNotEmpty) {
        albumArt = images[0]['url'] as String?;
      }
    }

    String artistName = 'Unknown';
    final artists = json['artists'] as List<dynamic>?;
    if (artists != null && artists.isNotEmpty) {
      artistName = artists[0]['name'] as String? ?? 'Unknown';
    }

    // Get external URLs (Spotify URL)
    String? spotifyUrl;
    final externalUrls = json['external_urls'] as Map<String, dynamic>?;
    if (externalUrls != null) {
      spotifyUrl = externalUrls['spotify'] as String?;
    }

    return SpotifyTrack(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      artist: artistName,
      album: album?['name'] as String?,
      albumArt: albumArt,
      durationMs: json['duration_ms'] as int?,
      spotifyUrl: spotifyUrl,
    );
  }
}

class SpotifyAudioFeatures {
  final double tempo; // BPM
  final int key; // 0-11: C, C#, D, D#, E, F, F#, G, G#, A, A#, B
  final int mode; // 0 = minor, 1 = major
  final int timeSignature;

  SpotifyAudioFeatures({
    required this.tempo,
    required this.key,
    required this.mode,
    required this.timeSignature,
  });

  factory SpotifyAudioFeatures.fromJson(Map<String, dynamic> json) {
    return SpotifyAudioFeatures(
      tempo: (json['tempo'] as num?)?.toDouble() ?? 0,
      key: json['key'] as int? ?? 0,
      mode: json['mode'] as int? ?? 1,
      timeSignature: json['time_signature'] as int? ?? 4,
    );
  }

  int get bpm => tempo.round();

  String get musicalKey {
    const keys = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];
    final keyName = keys[key];
    final modeName = mode == 1 ? 'major' : 'minor';
    return '$keyName $modeName';
  }

  String get camelotKey {
    // Convert to Camelot wheel notation
    // Major: I, II, II# = 11B, 12B, 1B...
    // Minor: i, ii, iiio = 11A, 12A, 1A...
    if (mode == 1) {
      // Major
      final camelot = (key + 8) % 12 + 1;
      return '${camelot}B';
    } else {
      // Minor
      final camelot = (key + 8) % 12 + 1;
      return '${camelot}A';
    }
  }
}
