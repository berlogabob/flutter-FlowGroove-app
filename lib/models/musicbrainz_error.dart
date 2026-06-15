/// MusicBrainz API error types
sealed class MusicBrainzError implements Exception {
  const MusicBrainzError({
    required this.message,
    this.details,
    this.originalError,
  });

  final String message;
  final String? details;
  final Object? originalError;

  @override
  String toString() {
    if (details != null) {
      return 'MusicBrainzError: $message - $details';
    }
    return 'MusicBrainzError: $message';
  }
}

/// Generic MusicBrainz error (non-sealed for general use)
class MusicBrainzGenericError extends MusicBrainzError {
  const MusicBrainzGenericError({
    required super.message,
    super.details,
    super.originalError,
  });
}

/// Rate limit exceeded (429)
class RateLimitError extends MusicBrainzError {
  const RateLimitError({
    super.message = 'MusicBrainz rate limit exceeded',
    this.retryAfter,
  });

  final Duration? retryAfter;
}

/// Resource not found (404)
class NotFoundError extends MusicBrainzError {
  const NotFoundError({
    super.message = 'Resource not found',
  });
}

/// Server error (5xx)
class ServerError extends MusicBrainzError {
  const ServerError({
    this.statusCode,
    super.message = 'MusicBrainz server error',
  });

  final int? statusCode;
}

/// Network error
class NetworkError extends MusicBrainzError {
  const NetworkError({
    super.message = 'Network error occurred',
    super.originalError,
  });
}

/// Authentication error (401/403)
class AuthError extends MusicBrainzError {
  const AuthError({
    super.message = 'Authentication failed',
  });
}

/// Parse error (invalid response)
class ParseError extends MusicBrainzError {
  const ParseError({
    super.message = 'Failed to parse MusicBrainz response',
  });
}
