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
  bool _alwaysOn = false;

  /// Whether the wakelock is currently active.
  bool get isEnabled => _isEnabled;

  /// Whether the controller has been disposed.
  bool get isDisposed => _isDisposed;

  /// Whether the user's global "keep screen on" setting holds the lock.
  bool get alwaysOn => _alwaysOn;

  /// Apply the global "keep screen on" preference.
  ///
  /// When `true`, the wakelock is enabled and per-screen [disable] calls become
  /// no-ops so leaving a practice screen doesn't drop the lock. When `false`,
  /// the persistent lock is released and per-screen behaviour resumes.
  Future<void> setAlwaysOn({required bool value}) async {
    _alwaysOn = value;
    if (value) {
      await enable();
    } else {
      await disable();
    }
  }

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
    if (_alwaysOn) {
      // ponytail: user's global keep-screen-on holds the lock; ignore
      // per-screen disable so leaving a practice screen doesn't drop it.
      debugPrint('[Wakelock] alwaysOn active, ignoring disable');
      return true;
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
    if (_isEnabled) {
      await disable();
    }
    _isDisposed = true;
    debugPrint('[Wakelock] Controller disposed');
  }
}
