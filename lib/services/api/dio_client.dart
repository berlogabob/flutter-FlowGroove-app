import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/api_error.dart';

/// Dio client configuration and interceptors.
///
/// This class provides a centralized Dio instance with:
/// - Logging interceptor (debug mode only)
/// - Error handling interceptor
/// - Base options configuration
/// - Timeout settings
///
/// Usage:
/// ```dart
/// final dio = DioClient.instance.dio;
/// final response = await dio.get('/endpoint');
/// ```
class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;
  DioClient._internal();

  static DioClient get instance => _instance;

  late final Dio _dio;

  /// Get the configured Dio instance.
  Dio get dio => _dio;

  /// Initialize Dio with base configuration.
  void init({
    String? baseUrl,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Map<String, dynamic>? headers,
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? '',
        connectTimeout: connectTimeout ?? const Duration(seconds: 30),
        receiveTimeout: receiveTimeout ?? const Duration(seconds: 30),
        headers: headers ?? {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        responseType: ResponseType.json,
      ),
    );

    // Add interceptors only in debug mode
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          error: true,
          logPrint: (obj) => debugPrint('🌐 ${obj.toString()}'),
        ),
      );
    }

    // Add error handling interceptor
    _dio.interceptors.add(_ErrorHandlingInterceptor());

    debugPrint('✅ DioClient initialized');
  }

  /// Dispose of Dio resources.
  void dispose() {
    _dio.close();
    debugPrint('🗑️ DioClient disposed');
  }
}

/// Error handling interceptor for Dio.
///
/// Converts Dio exceptions to ApiError objects.
class _ErrorHandlingInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final apiError = _handleDioException(err);
    handler.reject(apiError);
  }

  ApiError _handleDioException(DioException error) {
    String message;
    ErrorType type;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'Connection timed out. Please try again.';
        type = ErrorType.network;
        break;

      case DioExceptionType.connectionError:
        message = 'Unable to connect. Please check your internet connection.';
        type = ErrorType.network;
        break;

      case DioExceptionType.badResponse:
        message = _handleBadResponse(error.response);
        type = _getResponseErrorType(error.response?.statusCode);
        break;

      case DioExceptionType.cancel:
        message = 'Request cancelled.';
        type = ErrorType.unknown;
        break;

      case DioExceptionType.badCertificate:
        message = 'Security certificate error.';
        type = ErrorType.network;
        break;

      case DioExceptionType.unknown:
      default:
        message = 'An unexpected error occurred.';
        type = ErrorType.unknown;
        break;
    }

    return ApiError(
      type: type,
      message: message,
      details: error.message,
      originalException: error,
      stackTrace: error.stackTrace,
    );
  }

  String _handleBadResponse(Response? response) {
    if (response == null) {
      return 'No response from server.';
    }

    final statusCode = response.statusCode ?? 0;
    final data = response.data;

    // Try to extract error message from response
    String? serverMessage;
    if (data is Map<String, dynamic>) {
      serverMessage = data['message'] as String? ??
          data['error'] as String? ??
          data['error_description'] as String?;
    }

    if (serverMessage != null && serverMessage.isNotEmpty) {
      return serverMessage;
    }

    // Default messages based on status code
    switch (statusCode) {
      case 400:
        return 'Bad request. Please check your input.';
      case 401:
        return 'Unauthorized. Please log in again.';
      case 403:
        return 'Access denied. You don\'t have permission.';
      case 404:
        return 'Resource not found.';
      case 409:
        return 'Conflict. The resource already exists.';
      case 422:
        return 'Validation failed. Please check your input.';
      case 429:
        return 'Too many requests. Please try again later.';
      case 500:
        return 'Server error. Please try again later.';
      case 502:
        return 'Bad gateway. Server is temporarily unavailable.';
      case 503:
        return 'Service unavailable. Please try again later.';
      default:
        return 'Request failed with status code $statusCode.';
    }
  }

  ErrorType _getResponseErrorType(int? statusCode) {
    if (statusCode == null) {
      return ErrorType.unknown;
    }

    if (statusCode >= 400 && statusCode < 500) {
      return ErrorType.validation;
    } else if (statusCode >= 500) {
      return ErrorType.server;
    }

    return ErrorType.unknown;
  }
}

/// Extension methods for Dio to simplify common operations.
extension DioExtensions on Dio {
  /// GET request with automatic error handling.
  Future<dynamic> getSafe(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data;
    } on ApiError {
      rethrow;
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  /// POST request with automatic error handling.
  Future<dynamic> postSafe(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data;
    } on ApiError {
      rethrow;
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  /// PUT request with automatic error handling.
  Future<dynamic> putSafe(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data;
    } on ApiError {
      rethrow;
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  /// DELETE request with automatic error handling.
  Future<dynamic> deleteSafe(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data;
    } on ApiError {
      rethrow;
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }
}
