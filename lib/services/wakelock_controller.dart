/// Wakelock controller service for keeping screen on during practice sessions.
///
/// Wraps `wakelock_plus` with safe enable/disable semantics, debug logging,
/// and graceful degradation on unsupported platforms (web browsers without
/// Screen Wake Lock API).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Service that manages wakelock state for the app.
///
/// Usage:
/// ```dart
/// final wakelock = WakelockController();
/// final screen = Object();
/// await wakelock.setScreenVisible(screen, visible: true);
/// await wakelock.setScreenVisible(screen, visible: false);
/// ```
class WakelockController {
  bool _isEnabled = false;
  bool _isDisposed = false;
  bool _alwaysOn = false;
  final Set<Object> _visibleScreens = {};
  Future<bool> _pending = Future.value(true);

  /// Each visible screen holds its own lock, independently of playback.
  Future<void> setScreenVisible(Object screen, {required bool visible}) async {
    if (_isDisposed) return;
    if (visible) {
      _visibleScreens.add(screen);
      // Browsers may release the platform lock while the document is hidden.
      await _setEnabled(true, force: true);
    } else {
      _visibleScreens.remove(screen);
      await disable();
    }
  }

  Future<bool> _setEnabled(bool enabled, {bool force = false}) {
    return _pending = _pending.then((_) async {
      if (_isDisposed) return false;
      if (!enabled && (_alwaysOn || _visibleScreens.isNotEmpty)) return true;
      if (!force && _isEnabled == enabled) return true;
      try {
        await WakelockPlus.toggle(enable: enabled);
        _isEnabled = enabled;
        return true;
      } catch (e) {
        debugPrint('[Wakelock] Failed to set enabled=$enabled: $e');
        return false;
      }
    });
  }

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
  Future<bool> enable() => _setEnabled(true);

  /// Release a playback lock, preserving visible screens and the global setting.
  Future<bool> disable() => _setEnabled(false);

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
    _alwaysOn = false;
    _visibleScreens.clear();
    await disable();
    _isDisposed = true;
    debugPrint('[Wakelock] Controller disposed');
  }
}

/// Route and app visibility ownership shared by the two metronome views.
class ScreenWakelock extends StatefulWidget {
  const ScreenWakelock({
    required this.controller,
    required this.isPlaying,
    required this.onWebResume,
    required this.child,
    super.key,
  });

  final WakelockController controller;
  final bool isPlaying;
  final VoidCallback onWebResume;
  final Widget child;

  @override
  State<ScreenWakelock> createState() => _ScreenWakelockState();
}

class _ScreenWakelockState extends State<ScreenWakelock>
    with WidgetsBindingObserver {
  bool _routeVisible = false;
  bool _foreground = true;
  bool _hiddenWhilePlaying = false;
  bool _timingWarning = false;

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground =
        state == null ||
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = ModalRoute.isCurrentOf(context) ?? true;
    if (_routeVisible == visible) return;
    _routeVisible = visible;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateLock();
    });
  }

  void _updateLock() {
    unawaited(
      widget.controller.setScreenVisible(
        this,
        visible: _routeVisible && _foreground,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) return;
    _foreground = state == AppLifecycleState.resumed;
    if (kIsWeb && !_foreground && widget.isPlaying && _routeVisible) {
      _hiddenWhilePlaying = true;
      setState(() => _timingWarning = true);
    }
    _updateLock();
    if (kIsWeb && _foreground && _routeVisible && _hiddenWhilePlaying) {
      _hiddenWhilePlaying = false;
      if (widget.isPlaying) widget.onWebResume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.controller.setScreenVisible(this, visible: false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_timingWarning && widget.isPlaying)
          Material(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: const SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Text('Keep this tab visible for exact timing'),
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
