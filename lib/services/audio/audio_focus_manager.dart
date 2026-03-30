/// Audio focus management for metronome
///
/// Handles audio interruptions (phone calls, notifications) gracefully.
/// Platform-specific implementation:
/// - Android: AudioManager.requestAudioFocus()
/// - iOS: AVAudioSession.setCategory()
/// - Web: No-op (browser handles focus)
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../analytics/metronome_analytics.dart';

/// Manages audio focus for metronome playback
class AudioFocusManager {
  static final AudioFocusManager _instance = AudioFocusManager._internal();
  factory AudioFocusManager() => _instance;
  AudioFocusManager._internal();

  bool _hasFocus = false;
  bool _isPaused = false;
  Function(bool hasFocus)? onFocusChanged;
  Function()? onShouldPause;
  Function()? onShouldResume;

  /// Check if audio focus is currently held
  bool get hasFocus => _hasFocus;

  /// Request audio focus
  /// Returns true if focus was granted
  Future<bool> requestFocus() async {
    if (_hasFocus) return true;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Android: Use platform channel to request audio focus
        final result = await const MethodChannel('com.flowgroove/audio')
            .invokeMethod('requestAudioFocus');
        _hasFocus = result == true;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        // iOS: Audio session is configured at app level
        // Focus is automatically managed
        _hasFocus = true;
      } else {
        // Web/Desktop: Assume focus is available
        _hasFocus = true;
      }

      if (_hasFocus) {
        debugPrint('[AudioFocus] Focus acquired');
        await MetronomeAnalytics.logAudioFocusEvent(eventType: 'gain');
        onFocusChanged?.call(true);
      }

      return _hasFocus;
    } catch (e) {
      debugPrint('[AudioFocus] Failed to request focus: $e');
      // Assume focus is available on error (graceful degradation)
      _hasFocus = true;
      return true;
    }
  }

  /// Handle audio focus loss
  /// [transient] - true if temporary (e.g., notification), false if permanent (e.g., phone call)
  void handleFocusLoss({bool transient = true}) {
    if (!_hasFocus) return;

    _hasFocus = false;
    debugPrint('[AudioFocus] Focus lost (transient: $transient)');

    if (!transient) {
      // Permanent focus loss (phone call) - pause metronome
      _isPaused = true;
      onShouldPause?.call();
    }

    MetronomeAnalytics.logAudioFocusEvent(
      eventType: transient ? 'loss_transient' : 'loss',
    );
    onFocusChanged?.call(false);
  }

  /// Handle audio focus regain
  void handleFocusGain() {
    _hasFocus = true;
    debugPrint('[AudioFocus] Focus regained');

    if (_isPaused) {
      _isPaused = false;
      onShouldResume?.call();
    }

    MetronomeAnalytics.logAudioFocusEvent(eventType: 'gain');
    onFocusChanged?.call(true);
  }

  /// Release audio focus
  Future<void> releaseFocus() async {
    if (!_hasFocus) return;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await const MethodChannel('com.flowgroove/audio')
            .invokeMethod('abandonAudioFocus');
      }

      _hasFocus = false;
      debugPrint('[AudioFocus] Focus released');
    } catch (e) {
      debugPrint('[AudioFocus] Failed to release focus: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    releaseFocus();
    onFocusChanged = null;
    onShouldPause = null;
    onShouldResume = null;
  }
}
