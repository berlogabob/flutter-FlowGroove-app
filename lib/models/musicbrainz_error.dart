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
    String message = 'MusicBrainz rate limit exceeded',
    this.retryAfter,
  }) : super(message: message);

  final Duration? retryAfter;
}

/// Resource not found (404)
class NotFoundError extends MusicBrainzError {
  const NotFoundError({
    String message = 'Resource not found',
  }) : super(message: message);
}

/// Server error (5xx)
class ServerError extends MusicBrainzError {
  const ServerError({
    this.statusCode,
    String message = 'MusicBrainz server error',
  }) : super(message: message);

  final int? statusCode;
}

/// Network error
class NetworkError extends MusicBrainzError {
  const NetworkError({
    String message = 'Network error occurred',
    Object? originalError,
  }) : super(message: message, originalError: originalError);
}

/// Authentication error (401/403)
class AuthError extends MusicBrainzError {
  const AuthError({
    String message = 'Authentication failed',
  }) : super(message: message);
}

/// Parse error (invalid response)
class ParseError extends MusicBrainzError {
  const ParseError({
    String message = 'Failed to parse MusicBrainz response',
  }) : super(message: message);
}
