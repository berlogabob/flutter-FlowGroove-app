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
final wakelockProvider = Provider<WakelockController>((ref) {
  final controller = WakelockController();
  ref.onDispose(controller.dispose);
  return controller;
});
