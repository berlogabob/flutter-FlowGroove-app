import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/api_error.dart';

/// Represents the current state of error handling.
class ErrorState {
  /// The current error, if any.
  final ApiError? error;

  /// A list of all errors that have occurred (for logging).
  final List<ApiError> errorHistory;

  /// Whether an error is currently being displayed.
  final bool hasError;

  const ErrorState({this.error, List<ApiError>? errorHistory})
    : errorHistory = errorHistory ?? const [],
      hasError = error != null;

  /// Creates a copy of this state with the given fields replaced.
  ErrorState copyWith({ApiError? error, List<ApiError>? errorHistory}) {
    return ErrorState(
      error: error ?? this.error,
      errorHistory: errorHistory ?? this.errorHistory,
    );
  }

  /// Clears the current error but preserves history.
  ErrorState clear() {
    return ErrorState(errorHistory: errorHistory);
  }

  /// Adds an error to the history.
  ErrorState addToHistory(ApiError newError) {
    final updatedHistory = [...errorHistory, newError];
    // Keep only the last 100 errors
    final trimmedHistory = updatedHistory.length > 100
        ? updatedHistory.sublist(updatedHistory.length - 100)
        : updatedHistory;
    return ErrorState(error: newError, errorHistory: trimmedHistory);
  }
}

/// Notifier for managing application-wide error state.
///
/// This provider handles error display, logging, and clearing.
///
/// Usage:
/// ```dart
/// // In a widget
/// final errorNotifier = ref.read(errorNotifierProvider.notifier);
/// errorNotifier.handleError(ApiError.network());
///
/// // Watch for errors
/// final errorState = ref.watch(errorNotifierProvider);
/// if (errorState.hasError) {
///   showErrorBanner(errorState.error!);
/// }
/// ```
class ErrorNotifier extends Notifier<ErrorState> {
  @override
  ErrorState build() {
    return const ErrorState();
  }

  /// Handles an error by updating state and logging.
  ///
  /// This method:
  /// 1. Updates the current error state
  /// 2. Adds the error to history
  /// 3. Logs the error for debugging
  void handleError(ApiError error) {
    state = state.addToHistory(error);
    _logError(error);
  }

  /// Handles an error from an exception.
  ///
  /// Converts the exception to an [ApiError] and calls [handleError].
  void handleException(Object exception, {StackTrace? stackTrace}) {
    final error = ApiError.fromException(exception, stackTrace: stackTrace);
    handleError(error);
  }

  /// Clears the current error.
  ///
  /// This should be called when the user dismisses an error or
  /// when navigating away from an error state.
  void clearError() {
    state = state.clear();
  }

  /// Clears all errors including history.
  void clearAll() {
    state = const ErrorState();
  }

  /// Gets the error history for debugging purposes.
  List<ApiError> get errorHistory => state.errorHistory;

  /// Logs an error to the console in debug mode.
  void _logError(ApiError error) {
    if (kDebugMode) {
      debugPrint('┌─────────────────────────────────────────────────────────');
      debugPrint('│ ERROR: ${error.type.name}');
      debugPrint('│ Message: ${error.message}');
      if (error.details != null) {
        debugPrint('│ Details: ${error.details}');
      }
      if (error.originalException != null) {
        debugPrint('│ Original: ${error.originalException}');
      }
      if (error.stackTrace != null) {
        debugPrint('│ Stack: ${error.stackTrace}');
      }
      debugPrint('└─────────────────────────────────────────────────────────');
    }
  }

  @override
  void dispose() {
    // No resources to dispose
  }

  /// Exports error history for debugging.
  List<Map<String, dynamic>> exportErrorHistory() {
    return state.errorHistory.map((e) => e.toJson()).toList();
  }
}

/// Provider for the [ErrorNotifier].
///
/// This is a singleton provider that maintains application-wide error state.
final errorNotifierProvider = NotifierProvider<ErrorNotifier, ErrorState>(() {
  return ErrorNotifier();
});

/// Extension on [WidgetRef] for convenient error handling.
extension ErrorHandlingExtension on WidgetRef {
  /// Handles an error using the [ErrorNotifier].
  void handleError(ApiError error) {
    read(errorNotifierProvider.notifier).handleError(error);
  }

  /// Handles an exception using the [ErrorNotifier].
  void handleException(Object exception, {StackTrace? stackTrace}) {
    read(
      errorNotifierProvider.notifier,
    ).handleException(exception, stackTrace: stackTrace);
  }

  /// Clears the current error.
  void clearError() {
    read(errorNotifierProvider.notifier).clearError();
  }

  /// Watches the current error state.
  ErrorState get errorState => watch(errorNotifierProvider);

  /// Gets the current error, if any.
  ApiError? get currentError => errorState.error;

  /// Checks if there is a current error.
  bool get hasError => errorState.hasError;
}
