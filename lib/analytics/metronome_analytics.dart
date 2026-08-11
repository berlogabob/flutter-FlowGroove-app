/// Analytics events for metronome optimization monitoring.
///
/// Only the two events the app actually emits live here. Eight more
/// (first-beat latency, tone matrix, 2D beat modes, timer accuracy, feature
/// flags, error, session start/end) were written but never called from any
/// call site, so they were removed rather than left as a menu of events that
/// never fire. Re-add one when something is ready to call it.
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
        'success': success ? 1 : 0, // Firebase requires num, not bool
        'duration_ms': duration.inMilliseconds,
        'error': ?error,
        'optimized': MetronomeFeatureFlags.enableOptimizedAudio ? 1 : 0,
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
}
