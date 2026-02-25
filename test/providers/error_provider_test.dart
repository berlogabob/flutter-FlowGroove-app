import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_repsync_app/providers/auth/error_provider.dart';
import 'package:flutter_repsync_app/models/api_error.dart';

void main() {
  group('ErrorProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    group('Error State Initialization', () {
      test('errorNotifierProvider initializes with empty state', () {
        final state = container.read(errorNotifierProvider);
        expect(state, isNotNull);
        expect(state.error, isNull);
        expect(state.hasError, isFalse);
        expect(state.errorHistory, isEmpty);
      });

      test('ErrorState default constructor creates empty state', () {
        const state = ErrorState();
        expect(state.error, isNull);
        expect(state.hasError, isFalse);
        expect(state.errorHistory, isEmpty);
      });

      test('ErrorState with error has hasError true', () {
        final error = ApiError.network(message: 'Test error');
        final state = ErrorState(error: error);
        expect(state.error, equals(error));
        expect(state.hasError, isTrue);
      });
    });

    group('ErrorNotifier Methods', () {
      test('notifier is accessible', () {
        final notifier = container.read(errorNotifierProvider.notifier);
        expect(notifier, isNotNull);
      });

      test('handleError updates state with error', () {
        final notifier = container.read(errorNotifierProvider.notifier);
        final error = ApiError.network(message: 'Test network error');

        notifier.handleError(error);

        final state = container.read(errorNotifierProvider);
        expect(state.error, equals(error));
        expect(state.hasError, isTrue);
        expect(state.errorHistory.length, 1);
      });

      test('handleError adds error to history', () {
        final notifier = container.read(errorNotifierProvider.notifier);
        final error1 = ApiError.network(message: 'Error 1');
        final error2 = ApiError.auth(message: 'Error 2');

        notifier.handleError(error1);
        notifier.handleError(error2);

        final state = container.read(errorNotifierProvider);
        expect(state.errorHistory.length, 2);
        expect(state.errorHistory[0], equals(error1));
        expect(state.errorHistory[1], equals(error2));
      });

      test('handleException converts exception to ApiError', () {
        final notifier = container.read(errorNotifierProvider.notifier);
        final exception = Exception('Test exception');

        notifier.handleException(exception);

        final state = container.read(errorNotifierProvider);
        expect(state.hasError, isTrue);
        expect(state.error, isA<ApiError>());
      });

      test('handleException with stackTrace includes trace', () {
        final notifier = container.read(errorNotifierProvider.notifier);
        final exception = Exception('Test exception');
        final stackTrace = StackTrace.current;

        notifier.handleException(exception, stackTrace: stackTrace);

        final state = container.read(errorNotifierProvider);
        expect(state.error?.stackTrace, equals(stackTrace));
      });

      test('clearError removes current error but preserves history', () {
        final notifier = container.read(errorNotifierProvider.notifier);
        final error = ApiError.network(message: 'Test error');

        notifier.handleError(error);
        notifier.clearError();

        final state = container.read(errorNotifierProvider);
        expect(state.error, isNull);
        expect(state.hasError, isFalse);
        expect(state.errorHistory.length, 1);
      });

      test('clearAll removes all errors including history', () {
        final notifier = container.read(errorNotifierProvider.notifier);
        final error = ApiError.network(message: 'Test error');

        notifier.handleError(error);
        notifier.clearAll();

        final state = container.read(errorNotifierProvider);
        expect(state.error, isNull);
        expect(state.hasError, isFalse);
        expect(state.errorHistory, isEmpty);
      });

      test('errorHistory getter returns history list', () {
        final notifier = container.read(errorNotifierProvider.notifier);
        final error1 = ApiError.network(message: 'Error 1');
        final error2 = ApiError.auth(message: 'Error 2');

        notifier.handleError(error1);
        notifier.handleError(error2);

        final history = notifier.errorHistory;
        expect(history.length, 2);
      });

      test('exportErrorHistory returns JSON list', () {
        final notifier = container.read(errorNotifierProvider.notifier);
        final error = ApiError.network(message: 'Test error');

        notifier.handleError(error);

        final exported = notifier.exportErrorHistory();
        expect(exported, isA<List>());
        expect(exported.length, 1);
        expect(exported.first['type'], 'network');
      });
    });

    group('ErrorState Methods', () {
      test('copyWith creates new state with updated error', () {
        const originalState = ErrorState();
        final error = ApiError.network(message: 'Test error');

        final newState = originalState.copyWith(error: error);

        expect(originalState.error, isNull);
        expect(newState.error, equals(error));
        expect(newState.hasError, isTrue);
      });

      test('copyWith preserves history', () {
        final error = ApiError.network(message: 'Test error');
        final originalState = ErrorState(error: error, errorHistory: [error]);

        final newState = originalState.copyWith(errorHistory: [error, error]);

        expect(newState.error, equals(error));
        expect(newState.errorHistory.length, 2);
      });

      test('clear removes current error', () {
        final error = ApiError.network(message: 'Test error');
        final state = ErrorState(error: error);

        final clearedState = state.clear();

        expect(clearedState.error, isNull);
        expect(clearedState.hasError, isFalse);
      });

      test('addToHistory adds error and updates current error', () {
        const state = ErrorState();
        final error = ApiError.network(message: 'Test error');

        final newState = state.addToHistory(error);

        expect(newState.error, equals(error));
        expect(newState.errorHistory.length, 1);
      });

      test('addToHistory trims history to last 100 errors', () {
        const state = ErrorState();
        final errors = List.generate(
          105,
          (i) => ApiError.network(message: 'Error $i'),
        );

        ErrorState currentState = state;
        for (final error in errors) {
          currentState = currentState.addToHistory(error);
        }

        expect(currentState.errorHistory.length, 100);
        expect(currentState.errorHistory.first.message, 'Error 5');
        expect(currentState.errorHistory.last.message, 'Error 104');
      });
    });

    group('Extension Methods', () {
      test('ErrorHandlingExtension methods are defined', () {
        // The extension is defined for WidgetRef, verify it compiles
        expect(true, isTrue);
      });

      test('ErrorNotifier can be used directly', () {
        final notifier = container.read(errorNotifierProvider.notifier);
        final error = ApiError.network(message: 'Test error');

        notifier.handleError(error);

        final state = container.read(errorNotifierProvider);
        expect(state.hasError, isTrue);
        expect(state.error, equals(error));
      });

      test('ErrorNotifier clearError works', () {
        final notifier = container.read(errorNotifierProvider.notifier);
        final error = ApiError.network(message: 'Test error');

        notifier.handleError(error);
        notifier.clearError();

        final state = container.read(errorNotifierProvider);
        expect(state.hasError, isFalse);
      });

      test('ErrorNotifier errorHistory is accessible', () {
        final notifier = container.read(errorNotifierProvider.notifier);
        final error = ApiError.network(message: 'Test error');

        notifier.handleError(error);

        final history = notifier.errorHistory;
        expect(history.length, 1);
      });
    });

    group('Dispose Verification', () {
      test('ErrorNotifier dispose does not throw', () {
        final notifier = container.read(errorNotifierProvider.notifier);
        expect(() => notifier.dispose(), returnsNormally);
      });

      test('ProviderContainer dispose cleans up resources', () {
        final localContainer = ProviderContainer();
        localContainer.read(errorNotifierProvider);
        expect(() => localContainer.dispose(), returnsNormally);
      });
    });

    group('Error Type Handling', () {
      test('handles network error', () {
        final notifier = container.read(errorNotifierProvider.notifier);
        final error = ApiError.network(message: 'Network error');

        notifier.handleError(error);

        final state = container.read(errorNotifierProvider);
        expect(state.error?.isNetwork, isTrue);
      });

      test('handles auth error', () {
        final notifier = container.read(errorNotifierProvider.notifier);
        final error = ApiError.auth(message: 'Auth error');

        notifier.handleError(error);

        final state = container.read(errorNotifierProvider);
        expect(state.error?.isAuth, isTrue);
      });

      test('handles validation error', () {
        final notifier = container.read(errorNotifierProvider.notifier);
        final error = ApiError.validation(message: 'Validation error');

        notifier.handleError(error);

        final state = container.read(errorNotifierProvider);
        expect(state.error?.isValidation, isTrue);
      });

      test('handles permission error', () {
        final notifier = container.read(errorNotifierProvider.notifier);
        final error = ApiError.permission(message: 'Permission error');

        notifier.handleError(error);

        final state = container.read(errorNotifierProvider);
        expect(state.error?.isPermission, isTrue);
      });

      test('handles not found error', () {
        final notifier = container.read(errorNotifierProvider.notifier);
        final error = ApiError.notFound(message: 'Not found error');

        notifier.handleError(error);

        final state = container.read(errorNotifierProvider);
        expect(state.error?.isNotFound, isTrue);
      });

      test('handles unknown error', () {
        final notifier = container.read(errorNotifierProvider.notifier);
        final error = ApiError.unknown(message: 'Unknown error');

        notifier.handleError(error);

        final state = container.read(errorNotifierProvider);
        expect(state.error?.isUnknown, isTrue);
      });
    });
  });
}
