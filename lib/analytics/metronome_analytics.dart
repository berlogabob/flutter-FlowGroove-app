/// Analytics events for metronome optimization monitoring
///
/// Track these events to measure optimization success:
/// - Audio initialization success/failure
/// - First beat latency
/// - Audio focus events
/// - Feature usage (tone matrix, 2D beat modes)
/// - Error tracking
library;

import 'package:firebase_analytics/firebase_analytics.dart';
import '../config/metronome_feature_flags.dart';

/// Metronome analytics event tracker
class MetronomeAnalytics {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Log audio initialization
  static Future<void> logAudioInitialization({
    required bool success,
    required Duration duration,
    String? error,
  }) async {
    await _analytics.logEvent(
      name: 'metronome_audio_init',
      parameters: {
        'success': success,
        'duration_ms': duration.inMilliseconds,
        if (error != null) 'error': error,
        'optimized': MetronomeFeatureFlags.enableOptimizedAudio,
      },
    );
  }

  /// Log first beat latency
  static Future<void> logFirstBeatLatency({
    required Duration latency,
    required bool optimized,
  }) async {
    await _analytics.logEvent(
      name: 'metronome_first_beat',
      parameters: {
        'latency_ms': latency.inMilliseconds,
        'optimized': optimized,
        'target_met': latency.inMilliseconds < 50,
      },
    );
  }

  /// Log audio focus events
  static Future<void> logAudioFocusEvent({
    required String eventType, // 'gain', 'loss', 'loss_transient'
  }) async {
    await _analytics.logEvent(
      name: 'metronome_audio_focus',
      parameters: {
        'event_type': eventType,
      },
    );
  }

  /// Log tone matrix usage
  static Future<void> logToneMatrixUsage({
    required String action, // 'opened', 'preset_applied', 'custom_saved', 'test_played'
    String? presetName,
  }) async {
    await _analytics.logEvent(
      name: 'metronome_tone_matrix',
      parameters: {
        'action': action,
        if (presetName != null) 'preset': presetName,
      },
    );
  }

  /// Log 2D beat mode usage
  static Future<void> log2DBeatModeUsage({
    required String action, // 'opened', 'pattern_saved', 'pattern_loaded'
    required int accentBeats,
    required int regularBeats,
  }) async {
    await _analytics.logEvent(
      name: 'metronome_2d_beat_modes',
      parameters: {
        'action': action,
        'accent_beats': accentBeats,
        'regular_beats': regularBeats,
        'total_cells': accentBeats * regularBeats,
      },
    );
  }

  /// Log timer accuracy
  static Future<void> logTimerAccuracy({
    required int bpm,
    required double accuracyPercent,
    required int beatsMeasured,
  }) async {
    await _analytics.logEvent(
      name: 'metronome_timer_accuracy',
      parameters: {
        'bpm': bpm,
        'accuracy_percent': accuracyPercent,
        'beats_measured': beatsMeasured,
        'within_target': accuracyPercent <= 2.0,
      },
    );
  }

  /// Log feature flag status
  static Future<void> logFeatureFlags() async {
    final flags = MetronomeFeatureFlags.featureStatus;
    await _analytics.logEvent(
      name: 'metronome_feature_flags',
      parameters: flags.cast<String, Object>(),
    );
  }

  /// Log error
  static Future<void> logError({
    required String errorCode,
    required String errorMessage,
    String? stackTrace,
  }) async {
    await _analytics.logEvent(
      name: 'metronome_error',
      parameters: {
        'error_code': errorCode,
        'error_message': errorMessage,
        if (stackTrace != null) 'stack_trace': stackTrace,
      },
    );
  }

  /// Log user session start
  static Future<void> logSessionStart() async {
    await _analytics.logEvent(
      name: 'metronome_session_start',
      parameters: {
        'optimized': MetronomeFeatureFlags.enableOptimizedAudio,
      },
    );
  }

  /// Log user session end
  static Future<void> logSessionEnd({
    required Duration duration,
    required int songsPracticed,
  }) async {
    await _analytics.logEvent(
      name: 'metronome_session_end',
      parameters: {
        'duration_seconds': duration.inSeconds,
        'songs_practiced': songsPracticed,
      },
    );
  }
}
