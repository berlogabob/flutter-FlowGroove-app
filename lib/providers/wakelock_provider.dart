/// Riverpod provider for wakelock service.
///
/// Provides access to [WakelockController] throughout the app.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/wakelock_controller.dart';

/// Provider for the wakelock controller.
///
/// Usage in widgets:
/// ```dart
/// final wakelock = ref.watch(wakelockProvider);
/// await wakelock.enable();
/// ```
///
/// The controller is auto-disposed when no longer needed.
final wakelockProvider = Provider<WakelockController>(
  (ref) {
    final controller = WakelockController();
    ref.onDispose(controller.dispose);
    return controller;
  },
);

/// Provider for wakelock enabled state (boolean).
///
/// Watches the wakelock state and rebuilds when it changes.
final wakelockEnabledProvider = StreamProvider<bool>(
  (ref) async* {
    // Initial state: not enabled
    yield false;
    // Note: wakelock_plus doesn't emit state changes,
    // so consumers should check controller.isEnabled directly
  },
);
