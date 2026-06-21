import 'dart:async';

import 'package:flutter/foundation.dart' show VoidCallback, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../providers/metronome_runtime_providers.dart'
    show
        MetronomePlaybackClient,
        MetronomePlaybackConfig,
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
///     index/count-in bookkeeping. The UI tick path NEVER plays audio.
///
/// Route changes are bridged into recovery: when [AudioRouteMonitor] reports a
/// new route we (a) tell the sink via [NativeSoLoudSink.signalDeviceChanged],
/// which the scheduler observes and turns into a `recover()` (rebuilding the
/// SoLoud engine on the new default device), and (b) push an updated
/// [RenderConfig] with the new route's latency offset.
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
      _route = route;
      // Bridge route change -> scheduler recovery (rebuilds the engine on the
      // new default output device).
      _sink.signalDeviceChanged();
      // Re-push render config so the renderer uses the new route's latency.
      final config = _config;
      if (config != null) {
        _scheduler.update(_renderConfig(config));
      }
    });
  }

  void _startUiTick(MetronomePlaybackConfig config) {
    _uiScheduler.start(config.interval, _handleUiTick);
  }

  /// Visual-only tick. Mirrors `FlutterMetronomePlaybackClient._handleTick`
  /// index/count-in bookkeeping but performs NO audio playback (audio is owned
  /// by the scheduler/sink).
  void _handleUiTick() {
    try {
      final config = _config;
      final onTick = _onTick;
      if (config == null || onTick == null) return;

      final total = config.totalTicks;
      if (total <= 0) return;
      _tickIndex = (_tickIndex + 1) % total;
      final base = config.tickForIndex(_tickIndex);

      final countInTotalTicks = config.countInBars * total;
      final isCountIn = _countInTicks < countInTotalTicks;
      if (isCountIn) {
        _countInTicks++;
      }
      onTick(base);
    } catch (error, stackTrace) {
      debugPrint('[UnifiedEngine] ui tick error: $error\n$stackTrace');
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
