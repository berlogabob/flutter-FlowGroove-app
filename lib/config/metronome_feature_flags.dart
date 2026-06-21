/// Feature flags for metronome optimization rollout
///
/// Use these flags to gradually roll out new features:
/// 1. Start with internal testing (all true)
/// 2. Beta testers (all true)
/// 3. 10% rollout (enableOptimizedAudio only)
/// 4. 50% rollout (all true)
/// 5. 100% rollout (all true, then remove flags)
class MetronomeFeatureFlags {
  /// Use a buffered PCM timeline so audible tick placement is independent of
  /// Dart and platform timer jitter on every supported platform.
  ///
  /// DISABLED 2026-06-21 (Phase 0, concert-safe stabilization — see
  /// docs/superpowers/plans/2026-06-21-metronome-robustness.md). The PCM
  /// timeline feeds a SoLoud `setBufferStream` whose miniaudio output device is
  /// bound once at init and does NOT follow audio-route changes, so connecting
  /// Bluetooth headphones mid-play kills the stream permanently. Setting this to
  /// false routes Android through the native SoundPool engine
  /// (`AndroidMetronomeEngine`), which plays on USAGE_MEDIA and follows the
  /// system route automatically (survives Bluetooth). Re-enable only after
  /// stream-disconnect recovery is implemented (plan Phase 2.2/2.3).
  static const bool enablePcmTimelineEngine = false;

  /// Route metronome playback through the new unified sample-accurate engine
  /// ([UnifiedEnginePlaybackClient]: MetronomeScheduler + PcmClickRenderer +
  /// NativeSoLoudSink + AudioRouteMonitor). This is mutually exclusive with the
  /// legacy SoLoud chain (the unified sink calls a process-wide SoLoud.deinit()
  /// on recover/close), so when true the provider must NOT also build the legacy
  /// clients. Default false; flipped after review.
  static const bool enableUnifiedEngine = false;

  /// Enable audio pre-initialization and pre-warm
  /// Impact: 10x faster first beat (<50ms vs 500ms)
  /// Risk: LOW - Tested extensively
  static const bool enableOptimizedAudio = true;

  /// Enable tone matrix system with 6 frequency controls
  /// Impact: Professional-grade sound customization
  /// Risk: MEDIUM - New feature, needs user testing
  static const bool enableToneMatrix = true;

  /// Enable Mono Pulse design system
  /// Impact: Premium visual design
  /// Risk: LOW - Visual only, no functional changes
  static const bool enableMonoPulseTheme = false; // Gradual rollout

  /// Enable 2D beat mode grid editor
  /// Impact: Complex rhythm patterns
  /// Risk: MEDIUM - UX complexity
  static const bool enable2DBeatModes = true;

  /// Enable audio focus management
  /// Impact: Proper behavior during phone calls
  /// Risk: MEDIUM - Platform-specific code
  static const bool enableAudioFocus = true;

  /// Enable subdivision-based pitch patterns (H/l)
  /// Impact: Better rhythm clarity
  /// Risk: LOW - Pure logic change
  static const bool enableSubdivisionPitch = true;

  /// Check if all features are enabled
  static bool get allEnabled =>
      enablePcmTimelineEngine &&
      enableOptimizedAudio &&
      enableToneMatrix &&
      enableMonoPulseTheme &&
      enable2DBeatModes &&
      enableAudioFocus &&
      enableSubdivisionPitch;

  /// Get feature status as map for debugging
  static Map<String, bool> get featureStatus => {
    'enableOptimizedAudio': enableOptimizedAudio,
    'enablePcmTimelineEngine': enablePcmTimelineEngine,
    'enableToneMatrix': enableToneMatrix,
    'enableMonoPulseTheme': enableMonoPulseTheme,
    'enable2DBeatModes': enable2DBeatModes,
    'enableAudioFocus': enableAudioFocus,
    'enableSubdivisionPitch': enableSubdivisionPitch,
  };
}
