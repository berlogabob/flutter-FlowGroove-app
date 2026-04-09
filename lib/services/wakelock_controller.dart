/// Wakelock controller service for keeping screen on during practice sessions.
///
/// Wraps `wakelock_plus` with safe enable/disable semantics, debug logging,
/// and graceful degradation on unsupported platforms (web browsers without
/// Screen Wake Lock API).
library;

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Service that manages wakelock state for the app.
///
/// Usage:
/// ```dart
/// final wakelock = WakelockController();
/// await wakelock.enable();  // Call when metronome starts playing
/// await wakelock.disable(); // Call when metronome stops/pauses
/// ```
class WakelockController {
  bool _isEnabled = false;
  bool _isDisposed = false;

  /// Whether the wakelock is currently active.
  bool get isEnabled => _isEnabled;

  /// Whether the controller has been disposed.
  bool get isDisposed => _isDisposed;

  /// Enable the wakelock to prevent the screen from sleeping.
  ///
  /// Safe to call multiple times — only the first call has effect.
  /// Returns `true` if successfully enabled, `false` if unsupported or disposed.
  Future<bool> enable() async {
    if (_isDisposed) {
      debugPrint('[Wakelock] Cannot enable: controller disposed');
      return false;
    }
    if (_isEnabled) {
      debugPrint('[Wakelock] Already enabled, skipping');
      return true;
    }

    try {
      await WakelockPlus.enable();
      _isEnabled = true;
      debugPrint('[Wakelock] Enabled');
      return true;
    } catch (e) {
      debugPrint('[Wakelock] Failed to enable: $e');
      return false;
    }
  }

  /// Disable the wakelock to allow the screen to sleep.
  ///
  /// Safe to call multiple times — only the first call has effect.
  /// Returns `true` if successfully disabled, `false` if error.
  Future<bool> disable() async {
    if (_isDisposed) {
      debugPrint('[Wakelock] Cannot disable: controller disposed');
      return false;
    }
    if (!_isEnabled) {
      debugPrint('[Wakelock] Already disabled, skipping');
      return true;
    }

    try {
      await WakelockPlus.disable();
      _isEnabled = false;
      debugPrint('[Wakelock] Disabled');
      return true;
    } catch (e) {
      debugPrint('[Wakelock] Failed to disable: $e');
      return false;
    }
  }

  /// Toggle the wakelock state.
  Future<bool> toggle() async {
    if (_isEnabled) {
      return disable();
    } else {
      return enable();
    }
  }

  /// Check if wakelock is currently enabled at the platform level.
  Future<bool> get isEnabledPlatform async {
    try {
      return await WakelockPlus.enabled;
    } catch (e) {
      debugPrint('[Wakelock] Cannot check platform state: $e');
      return false;
    }
  }

  /// Dispose the controller and release the wakelock.
  Future<void> dispose() async {
    if (_isDisposed) return;
    await disable();
    _isDisposed = true;
    debugPrint('[Wakelock] Controller disposed');
  }
}
