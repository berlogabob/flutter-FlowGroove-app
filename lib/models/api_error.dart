import 'package:json_annotation/json_annotation.dart';

part 'api_error.g.dart';

/// Types of errors that can occur in the application.
@JsonEnum()
enum ErrorType {
  /// Network-related errors (no internet, timeout, etc.)
  network,

  /// Authentication errors (unauthorized, invalid credentials, etc.)
  auth,

  /// Validation errors (invalid input, missing required fields, etc.)
  validation,

  /// Permission errors (access denied, insufficient permissions)
  permission,

  /// Not found errors (resource doesn't exist)
  notFound,

  /// Unknown or unhandled errors
  unknown,
}

/// A standardized error class for the application.
///
/// This class provides a consistent way to represent errors across
/// the application, with typed error categories and user-friendly messages.
@JsonSerializable()
class ApiError implements Exception {
  /// The type of error that occurred.
  final ErrorType type;

  /// A user-friendly message describing the error.
  final String message;

  /// Additional details about the error (for debugging).
  final String? details;

  /// The original exception that caused this error, if any.
  @JsonKey(includeFromJson: false, includeToJson: false)
  final Object? originalException;

  /// The stack trace of the error, if available.
  @JsonKey(includeFromJson: false, includeToJson: false)
  final StackTrace? stackTrace;

  const ApiError({
    required this.type,
    required this.message,
    this.details,
    this.originalException,
    this.stackTrace,
  });

  /// Creates an [ApiError] from a network exception.
  factory ApiError.network({
    String message =
        'Unable to connect. Please check your internet connection.',
    Object? exception,
    StackTrace? stackTrace,
  }) {
    return ApiError(
      type: ErrorType.network,
      message: message,
      details: exception?.toString(),
      originalException: exception,
      stackTrace: stackTrace,
    );
  }

  /// Creates an [ApiError] from an authentication exception.
  factory ApiError.auth({
    String message = 'Authentication failed. Please sign in again.',
    Object? exception,
    StackTrace? stackTrace,
  }) {
    return ApiError(
      type: ErrorType.auth,
      message: message,
      details: exception?.toString(),
      originalException: exception,
      stackTrace: stackTrace,
    );
  }

  /// Creates an [ApiError] from a validation exception.
  factory ApiError.validation({
    required String message,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    return ApiError(
      type: ErrorType.validation,
      message: message,
      details: exception?.toString(),
      originalException: exception,
      stackTrace: stackTrace,
    );
  }

  /// Creates an [ApiError] from a permission exception.
  factory ApiError.permission({
    String message = 'You do not have permission to perform this action.',
    Object? exception,
    StackTrace? stackTrace,
  }) {
    return ApiError(
      type: ErrorType.permission,
      message: message,
      details: exception?.toString(),
      originalException: exception,
      stackTrace: stackTrace,
    );
  }

  /// Creates an [ApiError] for not found errors.
  factory ApiError.notFound({
    String message = 'The requested resource was not found.',
    Object? exception,
    StackTrace? stackTrace,
  }) {
    return ApiError(
      type: ErrorType.notFound,
      message: message,
      details: exception?.toString(),
      originalException: exception,
      stackTrace: stackTrace,
    );
  }

  /// Creates an [ApiError] for unknown errors.
  factory ApiError.unknown({
    String message = 'An unexpected error occurred. Please try again.',
    Object? exception,
    StackTrace? stackTrace,
  }) {
    return ApiError(
      type: ErrorType.unknown,
      message: message,
      details: exception?.toString(),
      originalException: exception,
      stackTrace: stackTrace,
    );
  }

  /// Creates an [ApiError] from any exception.
  ///
  /// This factory method attempts to map common exception types to
  /// appropriate [ErrorType] values.
  factory ApiError.fromException(Object e, {StackTrace? stackTrace}) {
    // If it's already an ApiError, return it
    if (e is ApiError) {
      return e;
    }

    final errorString = e.toString().toLowerCase();

    // Network-related errors
    if (errorString.contains('socket') ||
        errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('http') ||
        errorString.contains('unable to load')) {
      return ApiError.network(
        message: _getNetworkMessage(e),
        exception: e,
        stackTrace: stackTrace,
      );
    }

    // Authentication errors
    if (errorString.contains('auth') ||
        errorString.contains('unauthorized') ||
        errorString.contains('permission_denied') ||
        errorString.contains('invalid-credential') ||
        errorString.contains('user-not-found') ||
        errorString.contains('wrong-password') ||
        errorString.contains('user-disabled') ||
        errorString.contains('requires-recent-login')) {
      return ApiError.auth(
        message: _getAuthMessage(e),
        exception: e,
        stackTrace: stackTrace,
      );
    }

    // Validation errors
    if (errorString.contains('invalid') ||
        errorString.contains('validation') ||
        errorString.contains('required') ||
        errorString.contains('format')) {
      return ApiError.validation(
        message: _getValidationMessage(e),
        exception: e,
        stackTrace: stackTrace,
      );
    }

    // Not found errors
    if (errorString.contains('not found') ||
        errorString.contains('no document') ||
        errorString.contains('404')) {
      return ApiError.notFound(
        message: 'The requested resource was not found.',
        exception: e,
        stackTrace: stackTrace,
      );
    }

    // Default to unknown
    return ApiError.unknown(
      message: 'An unexpected error occurred: ${e.toString()}',
      exception: e,
      stackTrace: stackTrace,
    );
  }

  /// Gets a user-friendly message for network errors.
  static String _getNetworkMessage(Object e) {
    final errorString = e.toString().toLowerCase();
    if (errorString.contains('timeout')) {
      return 'Connection timed out. Please try again.';
    }
    if (errorString.contains('socket') || errorString.contains('connection')) {
      return 'Unable to connect. Please check your internet connection.';
    }
    return 'Network error. Please check your connection and try again.';
  }

  /// Gets a user-friendly message for authentication errors.
  static String _getAuthMessage(Object e) {
    final errorString = e.toString().toLowerCase();
    if (errorString.contains('user-not-found')) {
      return 'No account found with this email.';
    }
    if (errorString.contains('wrong-password')) {
      return 'Incorrect password. Please try again.';
    }
    if (errorString.contains('user-disabled')) {
      return 'This account has been disabled.';
    }
    if (errorString.contains('requires-recent-login')) {
      return 'Please sign in again to perform this action.';
    }
    if (errorString.contains('email-already-in-use')) {
      return 'An account with this email already exists.';
    }
    if (errorString.contains('weak-password')) {
      return 'Password is too weak. Please choose a stronger password.';
    }
    if (errorString.contains('invalid-email')) {
      return 'Invalid email address.';
    }
    return 'Authentication failed. Please sign in again.';
  }

  /// Gets a user-friendly message for validation errors.
  static String _getValidationMessage(Object e) {
    final errorString = e.toString().toLowerCase();
    if (errorString.contains('email')) {
      return 'Please enter a valid email address.';
    }
    if (errorString.contains('password')) {
      return 'Please enter a valid password.';
    }
    if (errorString.contains('required')) {
      return 'This field is required.';
    }
    return 'Invalid input. Please check your entries.';
  }

  /// Returns true if this is a network error.
  bool get isNetwork => type == ErrorType.network;

  /// Returns true if this is an authentication error.
  bool get isAuth => type == ErrorType.auth;

  /// Returns true if this is a validation error.
  bool get isValidation => type == ErrorType.validation;

  /// Returns true if this is a permission error.
  bool get isPermission => type == ErrorType.permission;

  /// Returns true if this is a not found error.
  bool get isNotFound => type == ErrorType.notFound;

  /// Returns true if this is an unknown error.
  bool get isUnknown => type == ErrorType.unknown;

  @override
  String toString() {
    final buffer = StringBuffer('ApiError(${type.name}): $message');
    if (details != null) {
      buffer.write(' [$details]');
    }
    return buffer.toString();
  }

  /// Converts this error to a JSON map for logging or serialization.
  Map<String, dynamic> toJson() => _$ApiErrorToJson(this);

  /// Creates an [ApiError] from a JSON map.
  factory ApiError.fromJson(Map<String, dynamic> json) =>
      _$ApiErrorFromJson(json);
}

/// Extension to provide user-friendly error messages.
extension ApiErrorExtension on ApiError {
  /// Gets a short title for the error.
  String get title {
    switch (type) {
      case ErrorType.network:
        return 'Connection Error';
      case ErrorType.auth:
        return 'Authentication Error';
      case ErrorType.validation:
        return 'Invalid Input';
      case ErrorType.permission:
        return 'Access Denied';
      case ErrorType.notFound:
        return 'Not Found';
      case ErrorType.unknown:
        return 'Error';
    }
  }

  /// Gets an appropriate icon for the error type.
  String get iconCode {
    switch (type) {
      case ErrorType.network:
        return 'wifi_off';
      case ErrorType.auth:
        return 'lock';
      case ErrorType.validation:
        return 'warning';
      case ErrorType.permission:
        return 'block';
      case ErrorType.notFound:
        return 'search_off';
      case ErrorType.unknown:
        return 'error';
    }
  }
}
