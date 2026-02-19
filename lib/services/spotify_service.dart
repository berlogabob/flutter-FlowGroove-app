import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'web_config.stub.dart' if (dart.library.html) 'web_config.web.dart';

/// Spotify Service for searching songs and getting audio features (BPM, key).
///
/// To enable Spotify:
/// 1. Go to https://developer.spotify.com/dashboard
/// 2. Create an app to get Client ID and Client Secret
/// 3. Add credentials to .env file (SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET)
///    OR for web: set window.env in web/config.js
class SpotifyService {
  /// Get Spotify Client ID from environment variables
  /// For web, also checks window.env object
  static String get _clientId {
    if (kIsWeb) {
      // Try dotenv first
      final fromDotenv = dotenv.env['SPOTIFY_CLIENT_ID'] ?? '';
      if (fromDotenv.isNotEmpty && fromDotenv != 'your_client_id_here') {
        return fromDotenv;
      }
      // Fallback to web config (window.env)
      final fromWeb = getWebConfig('SPOTIFY_CLIENT_ID');
      if (fromWeb.isNotEmpty && fromWeb != 'your_client_id_here') {
        return fromWeb;
      }
      return '';
    }
    return dotenv.env['SPOTIFY_CLIENT_ID'] ?? '';
  }

  /// Get Spotify Client Secret from environment variables
  /// For web, also checks window.env object
  static String get _clientSecret {
    if (kIsWeb) {
      // Try dotenv first
      final fromDotenv = dotenv.env['SPOTIFY_CLIENT_SECRET'] ?? '';
      if (fromDotenv.isNotEmpty && fromDotenv != 'your_client_secret_here') {
        return fromDotenv;
      }
      // Fallback to web config (window.env)
      final fromWeb = getWebConfig('SPOTIFY_CLIENT_SECRET');
      if (fromWeb.isNotEmpty && fromWeb != 'your_client_secret_here') {
        return fromWeb;
      }
      return '';
    }
    return dotenv.env['SPOTIFY_CLIENT_SECRET'] ?? '';
  }

  static const String _baseUrl = 'https://api.spotify.com/v1';

  /// Check if Spotify API is configured
  static bool get isConfigured =>
      _clientId.isNotEmpty &&
      _clientId != 'your_client_id_here' &&
      _clientSecret.isNotEmpty &&
      _clientSecret != 'your_client_secret_here';

  static String? _accessToken;
  static DateTime? _tokenExpiry;

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

      final response = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'grant_type=client_credentials',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'];
        final expiresIn = data['expires_in'] as int;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
        return true;
      }
    } catch (e) {
      // Authentication failed
    }
    return false;
  }

  static Future<List<SpotifyTrack>> search(String query) async {
    if (!await _authenticate()) return [];

    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = '$_baseUrl/search?q=$encodedQuery&type=track&limit=10';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tracks = data['tracks']['items'] as List<dynamic>? ?? [];
        return tracks.map((t) => SpotifyTrack.fromJson(t)).toList();
      } else if (response.statusCode == 403) {
        throw Exception('Spotify Premium required for API access');
      }
    } catch (e) {
      rethrow;
    }
    return [];
  }

  static Future<SpotifyAudioFeatures?> getAudioFeatures(String trackId) async {
    if (!await _authenticate()) return null;

    try {
      final url = '$_baseUrl/audio-features/$trackId';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 200) {
        return SpotifyAudioFeatures.fromJson(json.decode(response.body));
      }
    } catch (e) {
      // Failed to get audio features
    }
    return null;
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
    final images = json['album']['images'] as List<dynamic>?;
    if (images != null && images.isNotEmpty) {
      albumArt = images[0]['url'] as String?;
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
      album: json['album']['name'] as String?,
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
