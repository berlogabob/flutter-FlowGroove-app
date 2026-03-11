// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Notifier for managing application-wide error state.
///
/// This provider handles error display, logging, and clearing.
///
/// Usage:
/// ```dart
/// // In a widget
/// final errorNotifier = ref.read(errorStateProvider.notifier);
/// errorNotifier.handleError(ApiError.network());
///
/// // Watch for errors
/// final errorState = ref.watch(errorStateProvider);
/// if (errorState.hasError) {
///   showErrorBanner(errorState.error!);
/// }
/// ```

@ProviderFor(ErrorStateNotifier)
final errorStateProvider = ErrorStateNotifierProvider._();

/// Notifier for managing application-wide error state.
///
/// This provider handles error display, logging, and clearing.
///
/// Usage:
/// ```dart
/// // In a widget
/// final errorNotifier = ref.read(errorStateProvider.notifier);
/// errorNotifier.handleError(ApiError.network());
///
/// // Watch for errors
/// final errorState = ref.watch(errorStateProvider);
/// if (errorState.hasError) {
///   showErrorBanner(errorState.error!);
/// }
/// ```
final class ErrorStateNotifierProvider
    extends $NotifierProvider<ErrorStateNotifier, ErrorState> {
  /// Notifier for managing application-wide error state.
  ///
  /// This provider handles error display, logging, and clearing.
  ///
  /// Usage:
  /// ```dart
  /// // In a widget
  /// final errorNotifier = ref.read(errorStateProvider.notifier);
  /// errorNotifier.handleError(ApiError.network());
  ///
  /// // Watch for errors
  /// final errorState = ref.watch(errorStateProvider);
  /// if (errorState.hasError) {
  ///   showErrorBanner(errorState.error!);
  /// }
  /// ```
  ErrorStateNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'errorStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$errorStateNotifierHash();

  @$internal
  @override
  ErrorStateNotifier create() => ErrorStateNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ErrorState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ErrorState>(value),
    );
  }
}

String _$errorStateNotifierHash() =>
    r'4d980f8b6ae317b4442446281b47b5964a41ecf9';

/// Notifier for managing application-wide error state.
///
/// This provider handles error display, logging, and clearing.
///
/// Usage:
/// ```dart
/// // In a widget
/// final errorNotifier = ref.read(errorStateProvider.notifier);
/// errorNotifier.handleError(ApiError.network());
///
/// // Watch for errors
/// final errorState = ref.watch(errorStateProvider);
/// if (errorState.hasError) {
///   showErrorBanner(errorState.error!);
/// }
/// ```

abstract class _$ErrorStateNotifier extends $Notifier<ErrorState> {
  ErrorState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ErrorState, ErrorState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ErrorState, ErrorState>,
              ErrorState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
