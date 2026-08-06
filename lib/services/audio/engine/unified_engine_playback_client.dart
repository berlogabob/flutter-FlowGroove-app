import 'dart:async';

import 'package:flutter/foundation.dart' show VoidCallback, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/beat_mode.dart';
import '../../../providers/metronome_runtime_providers.dart'
    show
        MetronomeHapticsClient,
        MetronomePlaybackClient,
        MetronomePlaybackConfig,
        MetronomePlaybackTick,
        MetronomePlaybackTickCallback;
import '../wall_clock_scheduler.dart';
import 'audio_route_monitor.dart';
import 'latency_calibration.dart';
import 'metronome_scheduler.dart';
import 'pcm_click_renderer.dart';
import 'render_config.dart';
import 'render_config_mapper.dart';
import 'sinks/soloud_sink.dart';

/// Unified metronome playback client that drives audio through the new
/// sample-accurate engine ([MetronomeScheduler] + [PcmClickRenderer] +
/// [NativeSoLoudSink]) while keeping the existing [MetronomePlaybackClient]
/// surface (`start/update/resetPhase/stop/dispose`).
///
/// Audio and visuals are decoupled:
///   - Audio is rendered ahead of time by the scheduler/sink (sample accurate).
///   - The visual `onTick` is driven by a separate [WallClockScheduler] at
///     `config.interval`, mirroring `FlutterMetronomePlaybackClient`'s
///     index/count-in bookkeeping (including haptics, fired via the optional
///     [MetronomeHapticsClient]). The UI tick path NEVER plays audio.
///
/// Route changes are bridged into recovery: when [AudioRouteMonitor] reports a
/// route change (after the first emission) we (a) tell the sink via
/// [NativeSoLoudSink.signalDeviceChanged], which the scheduler observes and
/// turns into a `recover()` (rebuilding the SoLoud engine on the new default
/// device), and (b) push an updated [RenderConfig] with the new route's
/// latency offset.
///
/// [AudioRouteMonitor.routeChanges] emits the CURRENT route immediately on
/// listen (not just on subsequent changes), so the very first emission after
/// (re)subscribing is treated specially: it just resolves the actual starting
/// route (recomputing the [RenderConfig] for the correct latency) without
/// signalling a device change, since there is nothing to recover from at
/// start-of-playback. Only emissions that differ from the previously known
/// route trigger `signalDeviceChanged()`. Until that first emission lands,
/// the very first rendered chunk(s) use the default ([AudioRoute.speaker])
/// latency offset; this is corrected within about one chunk once the route
/// arrives, which is well inside the scheduler's buffer-ahead window.
///
/// IMPORTANT: [NativeSoLoudSink.recover]/close call a process-wide
/// `SoLoud.deinit()`, so this client must never be alive at the same time as
/// the legacy `MetronomeAudioEngine`-backed clients. The provider enforces this
/// by branching to the unified client before constructing the legacy chain.
class UnifiedEnginePlaybackClient implements MetronomePlaybackClient {
  UnifiedEnginePlaybackClient({
    PcmClickRenderer? renderer,
    NativeSoLoudSink? sink,
    AudioRouteMonitor? routeMonitor,
    this.haptics,
    int sampleRate = 48000,
  })  : _sampleRate = sampleRate,
        _renderer = renderer ?? PcmClickRenderer(sampleRate: sampleRate),
        _sink = sink ?? NativeSoLoudSink(),
        _routeMonitor = routeMonitor ?? AudioRouteMonitor() {
    _scheduler = MetronomeScheduler(
      sink: _sink,
      renderer: _renderer,
      sampleRate: _sampleRate,
    );
    _loadCalibration();
  }

  final int _sampleRate;
  final PcmClickRenderer _renderer;
  final NativeSoLoudSink _sink;
  final AudioRouteMonitor _routeMonitor;

  /// Optional haptics client. When non-null, [_handleUiTick] fires haptics
  /// mirroring `FlutterMetronomePlaybackClient._handleTick`'s logic.
  final MetronomeHapticsClient? haptics;
  late final MetronomeScheduler _scheduler;

  final WallClockScheduler _uiScheduler = WallClockScheduler();

  /// Latency calibration. Starts with in-memory defaults (user offset 0) and is
  /// swapped for the prefs-backed instance once [_loadCalibration] resolves, so
  /// `start` never blocks on async prefs.
  LatencyCalibration _cal = LatencyCalibration(prefs: _NullPrefs());
  bool _calLoaded = false;

  AudioRoute _route = AudioRoute.speaker;
  MetronomePlaybackConfig? _config;
  MetronomePlaybackTickCallback? _onTick;
  VoidCallback? _onStopped;
  StreamSubscription<AudioRoute>? _routeSub;

  /// Whether we've seen the first `routeChanges` emission since the last
  /// (re)subscribe. The first emission only reports the current route (no
  /// recovery needed); only later emissions represent an actual device
  /// switch. Reset in [start]/[stop] so each playback session starts fresh.
  bool _sawFirstRoute = false;

  int _tickIndex = -1;
  int _countInTicks = 0;
  bool _disposed = false;

  Future<void> _loadCalibration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_disposed) return;
      _cal = LatencyCalibration(prefs: prefs);
      _calLoaded = true;
      // If already running, push refreshed latency.
      if (_config != null) {
        _scheduler.update(_renderConfig(_config!));
      }
    } catch (e) {
      debugPrint('[UnifiedEngine] latency calibration load failed: $e');
    }
  }

  RenderConfig _renderConfig(MetronomePlaybackConfig c) =>
      renderConfigFromPlayback(
        c,
        route: _route,
        cal: _cal,
        sampleRate: _sampleRate,
      );

  @override
  Future<void> start(
    MetronomePlaybackConfig config, {
    required MetronomePlaybackTickCallback onTick,
    VoidCallback? onStopped,
    int initialTick = -1,
  }) async {
    _config = config;
    _onTick = onTick;
    _onStopped = onStopped;
    _tickIndex = initialTick;
    _countInTicks = 0;
    _sawFirstRoute = false;

    await _scheduler.start(_renderConfig(config));
    _startUiTick(config);
    _subscribeRoute();
  }

  @override
  Future<void> update(MetronomePlaybackConfig config) async {
    _config = config;
    _scheduler.update(_renderConfig(config));
    if (_onTick != null) {
      _startUiTick(config);
    }
  }

  @override
  Future<void> resetPhase(MetronomePlaybackConfig config) async {
    _config = config;
    _tickIndex = -1;
    _countInTicks = config.countInBars * config.totalTicks;
    _scheduler.update(_renderConfig(config));
    if (_onTick != null) {
      _startUiTick(config);
    }
  }

  @override
  Future<void> stop() async {
    _uiScheduler.stop();
    await _routeSub?.cancel();
    _routeSub = null;
    _sawFirstRoute = false;
    await _scheduler.stop();
    final onStopped = _onStopped;
    _onTick = null;
    onStopped?.call();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    _uiScheduler.dispose();
  }

  void _subscribeRoute() {
    _routeSub ??= _routeMonitor.routeChanges.listen((route) {
      // The platform route emitter sends the CURRENT route immediately on
      // listen, not only on changes. Treating that first emission as a
      // device change would trigger a spurious recover() (SoLoud
      // deinit+reopen) on every start(), causing an audible glitch.
      if (!_sawFirstRoute) {
        _sawFirstRoute = true;
        _route = route;
        // Resolve the real starting route's latency promptly (well within
        // the buffer-ahead window), without signalling recovery: nothing
        // has changed yet, there is nothing to recover from.
        final config = _config;
        if (config != null) {
          _scheduler.update(_renderConfig(config));
        }
        return;
      }
      if (route == _route) return;
      _route = route;
      // Bridge a real route change -> scheduler recovery (rebuilds the
      // engine on the new default output device).
      _sink.signalDeviceChanged();
      // Re-push render config so the renderer uses the new route's latency.
      final config = _config;
      if (config != null) {
        _scheduler.update(_renderConfig(config));
      }
    }, onError: (Object error) {
      // The route EventChannel is registered in Android's MainActivity only;
      // on iOS/macOS the platform side is missing, so this stream errors
      // (MissingPluginException). Without onError that escapes to the zone as
      // an unhandled async error. Playback is unaffected — it just means the
      // route stays at its default and route-change recovery never fires
      // there. Registering the channel in AppDelegate.swift is the real fix.
      debugPrint('[UnifiedEngine] route monitor unavailable: $error');
    });
  }

  void _startUiTick(MetronomePlaybackConfig config) {
    _uiScheduler.start(config.interval, _handleUiTick);
  }

  /// Visual-only tick. Mirrors `FlutterMetronomePlaybackClient._handleTick`
  /// index/count-in bookkeeping and haptics firing, but performs NO audio
  /// playback (audio is owned by the scheduler/sink).
  void _handleUiTick() {
    try {
      final config = _config;
      final onTick = _onTick;
      if (config == null || onTick == null) return;

      final total = config.totalTicks;
      if (total <= 0) return;
      // The scheduler jumps past targets missed during a stall rather than
      // replaying them; advance the beat index by the same amount or the
      // animation falls permanently behind the (sample-accurate) audio.
      final skipped = _uiScheduler.lastSkippedTicks;
      _tickIndex = (_tickIndex + 1 + skipped) % total;
      final base = config.tickForIndex(_tickIndex);

      final countInTotalTicks = config.countInBars * total;
      final isCountIn = _countInTicks < countInTotalTicks;
      if (isCountIn) {
        // Count skipped ticks too, else a stall stretches the count-in past
        // its bar.
        _countInTicks += 1 + skipped;
      }
      _fireHaptics(config, base);
      onTick(base);
    } catch (error, stackTrace) {
      debugPrint('[UnifiedEngine] ui tick error: $error\n$stackTrace');
    }
  }

  /// Mirrors `FlutterMetronomePlaybackClient._handleTick`'s haptics
  /// conditions: only when `config.hapticsEnabled` and the tick
  /// `shouldPlay`; subdivision ticks get a light `tick()`, main-beat ticks
  /// are dispatched by `BeatMode` (accent/normal/silent). Fires regardless of
  /// count-in, same as the legacy client.
  void _fireHaptics(MetronomePlaybackConfig config, MetronomePlaybackTick tick) {
    final client = haptics;
    if (client == null || !config.hapticsEnabled || !tick.shouldPlay) {
      return;
    }
    final beatIndex = tick.beatIndex;
    final subdivisionIndex = tick.subdivisionIndex;
    if (subdivisionIndex > 0) {
      client.tick();
      return;
    }
    final mode =
        (beatIndex < config.beatModes.length &&
            subdivisionIndex < config.beatModes[beatIndex].length)
        ? config.beatModes[beatIndex][subdivisionIndex]
        : BeatMode.normal;
    switch (mode) {
      case BeatMode.accent:
        client.heavyClick();
      case BeatMode.normal:
        client.mediumClick();
      case BeatMode.silent:
        break;
    }
  }

  // Visible for diagnostics/tests.
  bool get calibrationLoaded => _calLoaded;
}

/// A [SharedPreferences] stand-in used only as the in-memory default before the
/// real prefs instance loads. Reads return defaults; writes are no-ops. This
/// keeps [LatencyCalibration] (user offset 0 + route defaults) usable
/// synchronously without blocking `start`.
class _NullPrefs implements SharedPreferences {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #getInt ||
        name == #getBool ||
        name == #getDouble ||
        name == #getString) {
      return null;
    }
    if (name == #getKeys) return <String>{};
    if (name == #containsKey) return false;
    // setInt/setBool/etc. return Future<bool>; reload/commit/clear too.
    return Future<bool>.value(true);
  }
}
