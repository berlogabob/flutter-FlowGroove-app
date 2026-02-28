import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../models/api_error.dart';
import 'spotify_service.dart';

/// Spotify Proxy Service for secure API access.
///
/// This service provides a proxy layer between the client and Spotify API.
/// It supports two modes:
/// 1. Backend Proxy Mode: Routes requests through a secure backend server
/// 2. Direct Mode: Falls back to direct Spotify API calls (for development)
///
/// To enable backend proxy:
/// 1. Set SPOTIFY_PROXY_URL in .env to your backend proxy endpoint
/// 2. Deploy the backend proxy (see docs/SPOTIFY_PROXY_SETUP.md)
///
/// Security benefits of backend proxy:
/// - API credentials never exposed to client
/// - Rate limiting controlled server-side
/// - Request validation and sanitization
/// - Audit logging of all API calls
class SpotifyProxyService {
  /// Backend proxy URL (optional)
  /// If not set, falls back to direct Spotify API calls
  static String? get _proxyUrl {
    if (kIsWeb) return null; // Backend proxy not supported on web yet
    return dotenv.env['SPOTIFY_PROXY_URL'];
  }

  /// Check if backend proxy is configured
  static bool get isProxyConfigured =>
      _proxyUrl != null && _proxyUrl!.isNotEmpty;

  /// Search for tracks using proxy or direct API.
  ///
  /// If backend proxy is configured, routes request through proxy.
  /// Otherwise, falls back to direct SpotifyService call.
  static Future<List<SpotifyTrack>> search(String query) async {
    // Validate input
    if (query.isEmpty || query.length > 200) {
      throw ApiError.validation(
        message: 'Search query must be between 1 and 200 characters.',
      );
    }

    // Sanitize input to prevent injection
    final sanitizedQuery = query
        .replaceAll('<', '')
        .replaceAll('>', '')
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll('&', '');

    try {
      if (isProxyConfigured) {
        return await _searchViaProxy(sanitizedQuery);
      } else {
        // Fallback to direct API (development mode)
        debugPrint(
          'WARNING: Using direct Spotify API. Configure SPOTIFY_PROXY_URL for production.',
        );
        return await SpotifyService.search(sanitizedQuery);
      }
    } on ApiError {
      rethrow;
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  /// Get audio features using proxy or direct API.
  static Future<SpotifyAudioFeatures?> getAudioFeatures(String trackId) async {
    // Validate track ID format
    if (trackId.isEmpty || trackId.length > 50) {
      throw ApiError.validation(message: 'Invalid track ID format.');
    }

    // Sanitize track ID (alphanumeric only)
    final sanitizedId = trackId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

    try {
      if (isProxyConfigured) {
        return await _getAudioFeaturesViaProxy(sanitizedId);
      } else {
        // Fallback to direct API (development mode)
        return await SpotifyService.getAudioFeatures(sanitizedId);
      }
    } on ApiError {
      rethrow;
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  /// Search via backend proxy.
  static Future<List<SpotifyTrack>> _searchViaProxy(String query) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_proxyUrl/search'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({'query': query}),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw ApiError.network(
                message: 'Proxy request timed out. Please try again.',
              );
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tracks = data['tracks'] as List<dynamic>? ?? [];
        return tracks.map((t) => SpotifyTrack.fromJson(t)).toList();
      } else if (response.statusCode == 401) {
        throw ApiError.auth(
          message: 'Proxy authentication failed.',
          exception: 'HTTP ${response.statusCode}',
        );
      } else if (response.statusCode == 429) {
        throw ApiError.network(
          message: 'Rate limit exceeded. Please try again later.',
          exception: 'HTTP ${response.statusCode}',
        );
      } else {
        throw ApiError.network(
          message: 'Proxy request failed.',
          exception: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } on ApiError {
      rethrow;
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  /// Get audio features via backend proxy.
  static Future<SpotifyAudioFeatures?> _getAudioFeaturesViaProxy(
    String trackId,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_proxyUrl/audio-features/$trackId'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw ApiError.network(
                message: 'Proxy request timed out. Please try again.',
              );
            },
          );

      if (response.statusCode == 200) {
        return SpotifyAudioFeatures.fromJson(json.decode(response.body));
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw ApiError.network(
          message: 'Proxy request failed.',
          exception: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } on ApiError {
      rethrow;
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  /// Check if Spotify is configured (proxy or direct).
  static bool get isConfigured =>
      isProxyConfigured || SpotifyService.isConfigured;
}
