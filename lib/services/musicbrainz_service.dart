import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/musicbrainz_recording.dart';
import '../models/musicbrainz_error.dart';

/// MusicBrainz API Service
/// 
/// Provides access to MusicBrainz database for song metadata.
/// 
/// IMPORTANT: MusicBrainz has strict rate limits:
/// - 1 request per second
/// - Must provide User-Agent header
/// - Excessive requests will result in temporary bans
/// 
/// Usage:
/// ```dart
/// final service = MusicBrainzService();
/// final results = await service.searchRecording(
///   title: 'Bohemian Rhapsody',
///   artist: 'Queen',
/// );
/// ```
/// 
/// See: https://musicbrainz.org/doc/Development/XML_Web_Service/Rate_Limiting
class MusicBrainzService {
  final Dio _dio;
  
  static const String _baseUrl = 'https://musicbrainz.org/ws/2';
  static const String _userAgent = 'FlowGroove/1.0 (berloga.bob@gmail.com)';
  
  /// Rate limiting: minimum time between requests (1 second)
  static const Duration _rateLimitDelay = Duration(milliseconds: 1000);
  
  /// Maximum retries on rate limit
  static const int _maxRetries = 3;
  
  DateTime? _lastRequestTime;
  int _retryCount = 0;

  MusicBrainzService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              headers: {
                'User-Agent': _userAgent,
                'Accept': 'application/json',
              },
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ));

  /// Search recordings by title and artist
  /// 
  /// [title] - Song title to search for
  /// [artist] - Artist name (optional, improves accuracy)
  /// [limit] - Maximum results to return (default: 10, max: 100)
  /// [offset] - Result offset for pagination
  /// 
  /// Returns a list of [MusicBrainzRecording] matching the query.
  /// 
  /// Example:
  /// ```dart
  /// final results = await service.searchRecording(
  ///   title: 'Bohemian Rhapsody',
  ///   artist: 'Queen',
  ///   limit: 5,
  /// );
  /// ```
  Future<List<MusicBrainzRecording>> searchRecording({
    required String title,
    String? artist,
    int limit = 10,
    int offset = 0,
  }) async {
    // Build query string
    final queryParts = <String>['recording:"$title"'];
    if (artist != null && artist.isNotEmpty) {
      queryParts.add('artist:"$artist"');
    }
    
    final query = queryParts.join(' AND ');
    
    return await _search(
      query: query,
      limit: limit,
      offset: offset,
      inc: ['artists', 'releases', 'isrcs', 'aliases'],
    );
  }

  /// Search recordings by free-form query
  /// 
  /// [query] - Free-form search query (e.g., "Bohemian Rhapsody Queen")
  /// [limit] - Maximum results to return
  /// [offset] - Result offset
  /// 
  /// Less precise than [searchRecording] but more flexible.
  Future<List<MusicBrainzRecording>> searchByQuery({
    required String query,
    int limit = 10,
    int offset = 0,
  }) async {
    return await _search(
      query: query,
      limit: limit,
      offset: offset,
      inc: ['artists', 'releases', 'isrcs'],
    );
  }

  /// Search by ISRC (International Standard Recording Code)
  /// 
  /// [isrc] - ISRC code (e.g., "GBUM71029604")
  /// 
  /// Returns exact match or empty list.
  Future<List<MusicBrainzRecording>> searchByISRC(String isrc) async {
    return await _search(
      query: 'isrc:"$isrc"',
      limit: 5,
      inc: ['artists', 'releases'],
    );
  }

  /// Get recording by MusicBrainz ID
  ///
  /// [id] - MusicBrainz Recording ID (UUID)
  ///
  /// Returns single recording or throws [NotFoundError].
  Future<MusicBrainzRecording> getRecording(String id) async {
    await _enforceRateLimit();

    try {
      final response = await _dio.get(
        '$_baseUrl/recording/$id',
        queryParameters: {
          'fmt': 'json',
          'inc': 'artists+releases+isrcs+aliases',
        },
      );

      return MusicBrainzRecording.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundError(message: 'Recording not found');
      }
      throw _handleError(e);
    }
  }

  /// Internal search implementation
  Future<List<MusicBrainzRecording>> _search({
    required String query,
    required int limit,
    int offset = 0,
    List<String>? inc,
  }) async {
    await _enforceRateLimit();

    try {
      final response = await _dio.get(
        '$_baseUrl/recording',
        queryParameters: {
          'query': query,
          'fmt': 'json',
          'limit': limit.toString(),
          'offset': offset.toString(),
          'inc': inc?.join('+') ?? '',
        },
      );

      final data = response.data as Map<String, dynamic>;
      final recordings = data['recordings'] as List<dynamic>? ?? [];

      return recordings
          .map((r) => MusicBrainzRecording.fromJson(r as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Enforce rate limiting (1 request per second)
  Future<void> _enforceRateLimit() async {
    final now = DateTime.now();
    
    if (_lastRequestTime != null) {
      final elapsed = now.difference(_lastRequestTime!);
      
      if (elapsed < _rateLimitDelay) {
        final delay = _rateLimitDelay - elapsed;
        debugPrint('MusicBrainz rate limit: waiting ${delay.inMilliseconds}ms');
        await Future.delayed(Duration(milliseconds: delay.inMilliseconds));
      }
    }
    
    _lastRequestTime = DateTime.now();
  }

  /// Handle Dio errors and convert to MusicBrainzError
  MusicBrainzError _handleError(DioException error) {
    final statusCode = error.response?.statusCode;
    
    // Check for rate limit (429)
    if (statusCode == 429) {
      _retryCount++;
      
      if (_retryCount >= _maxRetries) {
        _retryCount = 0;
        return const RateLimitError(
          message: 'MusicBrainz rate limit exceeded after multiple retries',
        );
      }
      
      // Get retry-after header if present
      final retryAfter = error.response?.headers.value('retry-after');
      Duration? delay;
      
      if (retryAfter != null) {
        delay = Duration(seconds: int.tryParse(retryAfter) ?? 1);
      }
      
      return RateLimitError(retryAfter: delay);
    }
    
    // Not found (404)
    if (statusCode == 404) {
      return const NotFoundError();
    }
    
    // Server errors (5xx)
    if (statusCode != null && statusCode >= 500) {
      return ServerError(statusCode: statusCode);
    }
    
    // Authentication errors
    if (statusCode == 401 || statusCode == 403) {
      return const AuthError();
    }
    
    // Network errors
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return NetworkError(originalError: error);
    }
    
    // Default: generic error
    return MusicBrainzGenericError(
      message: 'MusicBrainz API error',
      details: error.message,
      originalError: error,
    );
  }

  /// Reset rate limit tracking (for testing)
  @visibleForTesting
  void resetRateLimit() {
    _lastRequestTime = null;
    _retryCount = 0;
  }

  /// Get current retry count (for debugging)
  @visibleForTesting
  int get retryCount => _retryCount;
}
