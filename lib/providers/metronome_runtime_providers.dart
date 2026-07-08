import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show
        TargetPlatform,
        VoidCallback,
        debugPrint,
        defaultTargetPlatform,
        kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../config/metronome_feature_flags.dart';
import '../models/beat_mode.dart';
import '../models/metronome_state.dart';
import '../services/audio/engine/unified_engine_playback_client.dart';
import '../services/audio/metronome_audio_engine.dart';
import '../services/audio/wall_clock_scheduler.dart';
import '../services/audio/web_audio_engine.dart';

abstract class MetronomeAudioClient {
  Future<void> initialize();

  Future<void> preWarmPlayers();

  Future<void> playClick({
    required bool isAccent,
    required String waveType,
    required double volume,
    double? accentFrequency,
    double? beatFrequency,
  });

  Future<void> playTest();

  Future<void> dispose();
}

class AudioEngineMetronomeAudioClient implements MetronomeAudioClient {
  AudioEngineMetronomeAudioClient();

  @override
  Future<void> initialize() {
    return MetronomeAudioEngine.instance.init();
  }

  @override
  Future<void> preWarmPlayers() {
    return MetronomeAudioEngine.instance.init();
  }

  @override
  Future<void> playClick({
    required bool isAccent,
    required String waveType,
    required double volume,
    double? accentFrequency,
    double? beatFrequency,
  }) {
    return MetronomeAudioEngine.instance.playClick(
      isAccent: isAccent,
      volume: volume,
      frequency: accentFrequency ?? beatFrequency,
    );
  }

  @override
  Future<void> playTest() {
    return MetronomeAudioEngine.instance.playClick(
      isAccent: false,
      volume: 0.8,
      frequency: 800,
    );
  }

  @override
  Future<void> dispose() {
    return MetronomeAudioEngine.instance.dispose();
  }
}

/// Web metronome audio client backed by the browser Web Audio API.
///
/// On web, `flutter_soloud` (used by [AudioEngineMetronomeAudioClient] and the
/// PCM timeline client) is unreliable and produces no sound without a dedicated
/// SoLoud web worker setup. This client routes clicks through the lightweight,
/// browser-safe [AudioEngine] instead, which lazily creates an `AudioContext`
/// on the first click (after a user gesture).
class WebAudioMetronomeAudioClient implements MetronomeAudioClient {
  WebAudioMetronomeAudioClient();

  final AudioEngine _engine = AudioEngine();

  @override
  Future<void> initialize() => _engine.initialize();

  @override
  Future<void> preWarmPlayers() => _engine.preWarmPlayers();

  @override
  Future<void> playClick({
    required bool isAccent,
    required String waveType,
    required double volume,
    double? accentFrequency,
    double? beatFrequency,
  }) {
    return _engine.playClick(
      isAccent: isAccent,
      waveType: waveType,
      volume: volume,
      accentFrequency: accentFrequency,
      beatFrequency: beatFrequency,
    );
  }

  @override
  Future<void> playTest() => _engine.playTest();

  @override
  Future<void> dispose() async => _engine.dispose();
}

abstract class MetronomeHapticsClient {
  void heavyClick();
  void mediumClick();
  void tick();
  void lightImpact();
}

class SystemMetronomeHapticsClient implements MetronomeHapticsClient {
  @override
  void heavyClick() {
    unawaited(_runHeavyClick());
  }

  Future<void> _runHeavyClick() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (error) {
      debugPrint('[MetronomeHaptics] heavyClick failed: $error');
    }
  }

  @override
  void mediumClick() {
    unawaited(_runMediumClick());
  }

  Future<void> _runMediumClick() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (error) {
      debugPrint('[MetronomeHaptics] mediumClick failed: $error');
    }
  }

  @override
  void tick() {
    unawaited(_runTick());
  }

  Future<void> _runTick() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (error) {
      debugPrint('[MetronomeHaptics] tick failed: $error');
    }
  }

  @override
  void lightImpact() {
    unawaited(_runLightImpact());
  }

  Future<void> _runLightImpact() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (error) {
      debugPrint('[MetronomeHaptics] lightImpact failed: $error');
    }
  }
}

final metronomeAudioClientProvider = Provider<MetronomeAudioClient>((ref) {
  // Web has no working flutter_soloud path; use the Web Audio API engine.
  final MetronomeAudioClient client = kIsWeb
      ? WebAudioMetronomeAudioClient()
      : AudioEngineMetronomeAudioClient();
  ref.onDispose(client.dispose);
  return client;
});

final metronomeHapticsProvider = Provider<MetronomeHapticsClient>((ref) {
  return SystemMetronomeHapticsClient();
});

typedef MetronomePlaybackTickCallback =
    void Function(MetronomePlaybackTick tick);

class MetronomePlaybackTick {
  const MetronomePlaybackTick({
    required this.index,
    required this.beatIndex,
    required this.subdivisionIndex,
    required this.isMainBeat,
    required this.shouldPlay,
    required this.frequency,
    this.isCountIn = false,
  });

  final int index;
  final int beatIndex;
  final int subdivisionIndex;
  final bool isMainBeat;
  final bool shouldPlay;
  final double frequency;
  final bool isCountIn;
}

class PcmTimelineMetronomePlaybackClient implements MetronomePlaybackClient {
  PcmTimelineMetronomePlaybackClient({required this.fallback});

  static const int _sampleRate = 44100;
  static const int _chunkMilliseconds = 1000;
  static const int _clickSamples = 1764;

  final MetronomePlaybackClient fallback;
  final WallClockScheduler _uiScheduler = WallClockScheduler();

  MetronomePlaybackConfig? _config;
  MetronomePlaybackTickCallback? _onTick;
  VoidCallback? _onStopped;
  AudioSource? _stream;
  SoundHandle? _handle;
  Timer? _feedTimer;
  int _audioTick = -1;
  int _uiTick = -1;
  int _countInTicksRemaining = 0;
  int _uiCountInTicksRemaining = 0;
  int _samplesUntilTick = 0;
  bool _running = false;
  bool _usingFallback = false;

  @override
  Future<void> start(
    MetronomePlaybackConfig config, {
    required MetronomePlaybackTickCallback onTick,
    VoidCallback? onStopped,
    int initialTick = -1,
  }) async {
    await stop();
    _config = config;
    _onTick = onTick;
    _onStopped = onStopped;
    _audioTick = initialTick;
    _uiTick = initialTick;
    _countInTicksRemaining = config.countInBars * config.totalTicks;
    _uiCountInTicksRemaining = _countInTicksRemaining;
    _samplesUntilTick = 0;
    _running = true;

    try {
      await MetronomeAudioEngine.instance.init();
      _stream = SoLoud.instance.setBufferStream(
        maxBufferSizeDuration: const Duration(seconds: 30),
        bufferingType: BufferingType.released,
        bufferingTimeNeeds: 0.15,
        sampleRate: _sampleRate,
      );
      _appendChunk();
      _appendChunk();
      _handle = SoLoud.instance.play(_stream!);
      _feedTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _appendChunk(),
      );
      _uiScheduler.start(config.interval, _handleUiTick);
    } catch (error) {
      debugPrint('[MetronomePlayback] PCM timeline failed: $error');
      _usingFallback = true;
      await fallback.start(
        config,
        onTick: onTick,
        onStopped: onStopped,
        initialTick: initialTick,
      );
    }
  }

  @override
  Future<void> update(MetronomePlaybackConfig config) async {
    _config = config;
    if (_usingFallback) {
      await fallback.update(config);
      return;
    }
    if (_running) _uiScheduler.start(config.interval, _handleUiTick);
  }

  @override
  Future<void> resetPhase(MetronomePlaybackConfig config) async {
    if (!_running) return;
    final onTick = _onTick;
    await start(config, onTick: onTick ?? (_) {}, onStopped: _onStopped);
  }

  @override
  Future<void> stop() async {
    final wasRunning = _running;
    _running = false;
    _feedTimer?.cancel();
    _feedTimer = null;
    _uiScheduler.stop();
    if (_usingFallback) await fallback.stop();
    _usingFallback = false;
    final handle = _handle;
    _handle = null;
    if (handle != null && SoLoud.instance.isInitialized) {
      await SoLoud.instance.stop(handle);
    }
    final stream = _stream;
    _stream = null;
    if (stream != null && SoLoud.instance.isInitialized) {
      await SoLoud.instance.disposeSource(stream);
    }
    _onTick = null;
    if (wasRunning) _onStopped = null;
  }

  @override
  void dispose() {
    unawaited(stop());
    _uiScheduler.dispose();
    fallback.dispose();
  }

  void _appendChunk() {
    if (!_running || _usingFallback || _stream == null) return;
    final config = _config;
    if (config == null) return;
    final samples = Int16List(_sampleRate * _chunkMilliseconds ~/ 1000);
    final intervalSamples = max(
      1,
      (_sampleRate * config.interval.inMicroseconds / 1000000).round(),
    );

    var cursor = 0;
    while (cursor < samples.length) {
      if (_samplesUntilTick > 0) {
        final advance = min(_samplesUntilTick, samples.length - cursor);
        cursor += advance;
        _samplesUntilTick -= advance;
        continue;
      }
      _audioTick = (_audioTick + 1) % config.totalTicks;
      final tick = config.tickForIndex(_audioTick);
      final isCountIn = _countInTicksRemaining > 0;
      if (isCountIn) _countInTicksRemaining--;
      if (tick.shouldPlay) {
        _mixClick(
          samples,
          cursor,
          isCountIn ? 2100 : tick.frequency,
          isCountIn ? min(1, config.volume + 0.15) : config.volume,
        );
      }
      _samplesUntilTick = intervalSamples;
    }
    SoLoud.instance.addAudioDataStream(_stream!, samples.buffer.asUint8List());
  }

  void _mixClick(Int16List output, int start, double frequency, double volume) {
    final count = min(_clickSamples, output.length - start);
    for (var index = 0; index < count; index++) {
      final time = index / _sampleRate;
      final envelope = index < 44
          ? index / 44
          : exp(-4 * (index - 44) / max(1, count - 44));
      final value = sin(2 * pi * frequency * time) * envelope * volume;
      output[start + index] = (value * 32767).round().clamp(-32768, 32767);
    }
  }

  void _handleUiTick() {
    final config = _config;
    final onTick = _onTick;
    if (!_running || config == null || onTick == null) return;
    _uiTick = (_uiTick + 1) % config.totalTicks;
    final base = config.tickForIndex(_uiTick);
    final isCountIn = _uiCountInTicksRemaining > 0;
    if (isCountIn) _uiCountInTicksRemaining--;
    onTick(
      MetronomePlaybackTick(
        index: base.index,
        beatIndex: base.beatIndex,
        subdivisionIndex: base.subdivisionIndex,
        isMainBeat: base.isMainBeat,
        shouldPlay: base.shouldPlay,
        frequency: base.frequency,
        isCountIn: isCountIn,
      ),
    );
  }
}

class MetronomePlaybackConfig {
  const MetronomePlaybackConfig({
    required this.bpm,
    required this.accentBeats,
    required this.regularBeats,
    required this.beatModes,
    required this.waveType,
    required this.volume,
    required this.accentEnabled,
    required this.accentFrequency,
    required this.beatFrequency,
    required this.accentBeatFrequency,
    required this.hapticsEnabled,
    this.countInBars = 0,
  });

  factory MetronomePlaybackConfig.fromState(MetronomeState state) {
    return MetronomePlaybackConfig(
      bpm: state.bpm,
      accentBeats: state.accentBeats,
      regularBeats: state.regularBeats,
      beatModes: state.beatModes,
      waveType: state.waveType,
      volume: state.volume,
      accentEnabled: state.accentEnabled,
      accentFrequency: state.accentFrequency,
      beatFrequency: state.beatFrequency,
      accentBeatFrequency: state.accentBeatFrequency,
      hapticsEnabled: state.hapticsEnabled,
      countInBars: state.countInBars,
    );
  }

  final int bpm;
  final int accentBeats;
  final int regularBeats;
  final List<List<BeatMode>> beatModes;
  final String waveType;
  final double volume;
  final bool accentEnabled;
  final double accentFrequency; // primary / main-beat pitch
  final double beatFrequency; // subdivision pitch
  final double accentBeatFrequency; // marked-accent (cyan) pitch
  final bool hapticsEnabled;
  final int countInBars;

  int get _safeAccentBeats => accentBeats.clamp(1, 12);

  int get _safeRegularBeats => regularBeats.clamp(1, 12);

  int get totalTicks => _safeAccentBeats * _safeRegularBeats;

  Duration get interval {
    final micros = (60000000 / bpm.clamp(1, 600) / _safeRegularBeats)
        .round()
        .clamp(500, 1500000);
    return Duration(microseconds: micros);
  }

  MetronomePlaybackTick tickForIndex(int tickIndex) {
    final normalizedIndex = _normalizeTickIndex(tickIndex);
    final subdivisionCount = _safeRegularBeats;
    final beatIndex = normalizedIndex ~/ subdivisionCount;
    final subdivisionIndex = normalizedIndex % subdivisionCount;
    final isMainBeat = subdivisionIndex == 0;
    final mode = _modeFor(beatIndex, subdivisionIndex);
    final shouldPlay = mode != BeatMode.silent;
    final frequency = resolveClickFrequency(
      mode: mode,
      isMainBeat: isMainBeat,
      accentEnabled: accentEnabled,
      primaryFrequency: accentFrequency,
      subdivisionFrequency: beatFrequency,
      accentFrequency: accentBeatFrequency,
    );

    return MetronomePlaybackTick(
      index: normalizedIndex,
      beatIndex: beatIndex,
      subdivisionIndex: subdivisionIndex,
      isMainBeat: isMainBeat,
      shouldPlay: shouldPlay,
      frequency: frequency,
    );
  }

  Map<String, Object?> toPlatformMap({required int initialTick}) {
    return <String, Object?>{
      'initialTick': initialTick,
      'intervalMicros': interval.inMicroseconds,
      'waveType': waveType,
      'volume': volume.clamp(0.0, 1.0),
      'hapticsEnabled': hapticsEnabled,
      'ticks': List<Map<String, Object?>>.generate(totalTicks, (index) {
        final tick = tickForIndex(index);
        return <String, Object?>{
          'index': tick.index,
          'shouldPlay': tick.shouldPlay,
          'frequency': tick.frequency,
        };
      }),
    };
  }

  int _normalizeTickIndex(int tickIndex) {
    final count = totalTicks;
    if (count <= 0) return 0;
    final normalized = tickIndex % count;
    return normalized < 0 ? normalized + count : normalized;
  }

  BeatMode _modeFor(int beatIndex, int subdivisionIndex) {
    if (beatIndex < beatModes.length &&
        subdivisionIndex < beatModes[beatIndex].length) {
      return beatModes[beatIndex][subdivisionIndex];
    }
    return BeatMode.normal;
  }
}

abstract class MetronomePlaybackClient {
  Future<void> start(
    MetronomePlaybackConfig config, {
    required MetronomePlaybackTickCallback onTick,
    VoidCallback? onStopped,
    int initialTick = -1,
  });

  Future<void> update(MetronomePlaybackConfig config);

  Future<void> resetPhase(MetronomePlaybackConfig config);

  Future<void> stop();

  void dispose();
}

class FlutterMetronomePlaybackClient implements MetronomePlaybackClient {
  FlutterMetronomePlaybackClient({
    required this._audioClient,
    required this._hapticsClient,
  });

  final MetronomeAudioClient _audioClient;
  final MetronomeHapticsClient _hapticsClient;

  final WallClockScheduler _scheduler = WallClockScheduler();
  MetronomePlaybackConfig? _config;
  MetronomePlaybackTickCallback? _onTick;
  int _tickIndex = -1;
  int _countInTicks = 0;
  int _consecutiveErrors = 0;

  @override
  Future<void> start(
    MetronomePlaybackConfig config, {
    required MetronomePlaybackTickCallback onTick,
    VoidCallback? onStopped,
    int initialTick = -1,
  }) async {
    await _audioClient.initialize();
    _config = config;
    _onTick = onTick;
    _tickIndex = initialTick;
    _countInTicks = 0;
    _scheduler.start(config.interval, _handleTick);
  }

  @override
  Future<void> update(MetronomePlaybackConfig config) async {
    _config = config;
    // Swap interval in place: restarting the scheduler here reset the phase, so
    // the next click fired a full interval after any button tap — an audible
    // pause (worst at slow tempos) that read as playback "freezing". `_tickIndex`
    // lives on this client, so the beat sequence stays continuous.
    if (_onTick != null) {
      _scheduler.updateInterval(config.interval);
    }
  }

  @override
  Future<void> resetPhase(MetronomePlaybackConfig config) async {
    _config = config;
    _tickIndex = -1;
    _countInTicks = config.countInBars * config.totalTicks;
    if (_onTick != null) {
      _scheduler.start(config.interval, _handleTick);
    }
  }

  @override
  Future<void> stop() async {
    _scheduler.stop();
    _onTick = null;
  }

  @override
  void dispose() {
    unawaited(stop());
    _scheduler.dispose();
    _consecutiveErrors = 0;
  }

  void _handleTick() {
    try {
      final config = _config;
      final onTick = _onTick;
      if (config == null || onTick == null) return;

      _tickIndex = (_tickIndex + 1) % config.totalTicks;
      final tick = config.tickForIndex(_tickIndex);

      // Count-in logic: skip audio playback during count-in bars
      final countInTotalTicks = config.countInBars * config.totalTicks;
      if (_countInTicks < countInTotalTicks) {
        // During count-in: fire haptics but skip audio
        if (config.hapticsEnabled && tick.shouldPlay) {
          final beatIndex = tick.beatIndex;
          final subdivisionIndex = tick.subdivisionIndex;
          if (subdivisionIndex > 0) {
            _hapticsClient.tick();
          } else {
            final mode =
                (beatIndex < config.beatModes.length &&
                    subdivisionIndex < config.beatModes[beatIndex].length)
                ? config.beatModes[beatIndex][subdivisionIndex]
                : BeatMode.normal;
            switch (mode) {
              case BeatMode.accent:
                _hapticsClient.heavyClick();
              case BeatMode.normal:
                _hapticsClient.mediumClick();
              case BeatMode.silent:
                break;
            }
          }
        }
        _countInTicks++;
        onTick(tick);
        _consecutiveErrors = 0;
        return;
      }

      // Normal playback (after count-in)
      if (tick.shouldPlay) {
        if (config.hapticsEnabled) {
          final beatIndex = tick.beatIndex;
          final subdivisionIndex = tick.subdivisionIndex;
          if (subdivisionIndex > 0) {
            _hapticsClient.tick();
          } else {
            final mode =
                (beatIndex < config.beatModes.length &&
                    subdivisionIndex < config.beatModes[beatIndex].length)
                ? config.beatModes[beatIndex][subdivisionIndex]
                : BeatMode.normal;
            switch (mode) {
              case BeatMode.accent:
                _hapticsClient.heavyClick();
              case BeatMode.normal:
                _hapticsClient.mediumClick();
              case BeatMode.silent:
                break;
            }
          }
        }
        unawaited(
          _audioClient.playClick(
            isAccent: tick.isMainBeat,
            waveType: config.waveType,
            volume: config.volume,
            accentFrequency: tick.frequency,
            beatFrequency: tick.frequency,
          ),
        );
      }

      onTick(tick);
      _consecutiveErrors = 0;
    } catch (error, stackTrace) {
      _consecutiveErrors++;
      debugPrint(
        '[MetronomePlayback] tick error ($_consecutiveErrors consecutive): $error\n$stackTrace',
      );
    }
  }
}

class PlatformMetronomePlaybackClient implements MetronomePlaybackClient {
  PlatformMetronomePlaybackClient({
    required this._fallback,
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel('com.flowgroove/metronome') {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  final MethodChannel _channel;
  final FlutterMetronomePlaybackClient _fallback;

  MetronomePlaybackConfig? _config;
  MetronomePlaybackTickCallback? _onTick;
  VoidCallback? _onStopped;
  bool _usingFallback = false;
  bool _isRunning = false;
  int _lastTickIndex = -1;

  bool get _canUseNative =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

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
    _lastTickIndex = initialTick;
    _isRunning = true;

    if (!_canUseNative || _usingFallback) {
      await _startFallback(config, onTick, onStopped, initialTick);
      return;
    }

    try {
      await _channel.invokeMethod<void>(
        'start',
        config.toPlatformMap(initialTick: initialTick),
      );
    } catch (error) {
      debugPrint('[MetronomePlayback] Native start failed: $error');
      _usingFallback = true;
      await _startFallback(config, onTick, onStopped, initialTick);
    }
  }

  @override
  Future<void> update(MetronomePlaybackConfig config) async {
    _config = config;

    if (!_isRunning) return;

    if (!_canUseNative || _usingFallback) {
      await _fallback.update(config);
      return;
    }

    try {
      await _channel.invokeMethod<void>(
        'update',
        config.toPlatformMap(initialTick: _lastTickIndex),
      );
    } catch (error) {
      debugPrint('[MetronomePlayback] Native update failed: $error');
      _usingFallback = true;
      try {
        await _channel.invokeMethod<void>('stop');
      } catch (_) {
        // Best-effort native stop before falling back to the Flutter scheduler.
      }
      final onTick = _onTick;
      if (onTick != null) {
        await _startFallback(config, onTick, _onStopped, _lastTickIndex);
      }
    }
  }

  @override
  Future<void> resetPhase(MetronomePlaybackConfig config) async {
    _config = config;
    _lastTickIndex = -1;
    if (!_isRunning) return;

    if (!_canUseNative || _usingFallback) {
      await _fallback.resetPhase(config);
      return;
    }

    try {
      await _channel.invokeMethod<void>(
        'update',
        config.toPlatformMap(initialTick: -1),
      );
    } catch (error) {
      debugPrint('[MetronomePlayback] Native phase reset failed: $error');
      _usingFallback = true;
      final onTick = _onTick;
      if (onTick != null) {
        await _startFallback(config, onTick, _onStopped, -1);
      }
    }
  }

  @override
  Future<void> stop() async {
    final wasRunning = _isRunning;
    _isRunning = false;
    _onTick = null;
    _onStopped = null;
    await _fallback.stop();

    if (_canUseNative && wasRunning) {
      try {
        await _channel.invokeMethod<void>('stop');
      } catch (error) {
        debugPrint('[MetronomePlayback] Native stop failed: $error');
      }
    }
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    unawaited(stop());
    _fallback.dispose();
  }

  Future<void> _startFallback(
    MetronomePlaybackConfig config,
    MetronomePlaybackTickCallback onTick,
    VoidCallback? onStopped,
    int initialTick,
  ) {
    return _fallback.start(
      config,
      onTick: onTick,
      onStopped: onStopped,
      initialTick: initialTick,
    );
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'tick':
        final arguments = call.arguments;
        if (arguments is Map) {
          final index = (arguments['index'] as num?)?.toInt();
          final config = _config;
          final onTick = _onTick;
          if (index != null && config != null && onTick != null) {
            _lastTickIndex = index;
            onTick(config.tickForIndex(index));
          }
        }
        return null;
      case 'stopped':
        if (_isRunning) {
          _isRunning = false;
          _onStopped?.call();
        }
        return null;
    }
    return null;
  }
}

/// Android plays through the native foreground service
/// ([PlatformMetronomePlaybackClient]) so the metronome survives backgrounding,
/// screen-off, and calls. All other native platforms keep the Dart unified
/// engine; web uses the Flutter/Web Audio fallback.
bool useNativeAndroidPlayback({
  required bool isWeb,
  required TargetPlatform platform,
}) => !isWeb && platform == TargetPlatform.android;

final metronomePlaybackClientProvider = Provider<MetronomePlaybackClient>((
  ref,
) {
  // Android: route through the native foreground service so playback survives
  // backgrounding, screen-off, and calls. Checked first so the unified engine
  // (flutter_soloud) is never constructed on Android.
  if (useNativeAndroidPlayback(
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
  )) {
    final fallback = FlutterMetronomePlaybackClient(
      audioClient: ref.read(metronomeAudioClientProvider),
      hapticsClient: ref.read(metronomeHapticsProvider),
    );
    final client = PlatformMetronomePlaybackClient(fallback: fallback);
    ref.onDispose(client.dispose);
    return client;
  }

  // Unified engine branch: built BEFORE the legacy chain so we never init the
  // legacy SoLoud-backed MetronomeAudioEngine alongside the unified sink (whose
  // recover()/close() call a process-wide SoLoud.deinit()). Mutually exclusive.
  // Checked first (even ahead of the web branch's fallback construction)
  // so the legacy `FlutterMetronomePlaybackClient` fallback is never
  // needlessly allocated when the unified engine is active.
  if (!kIsWeb && MetronomeFeatureFlags.enableUnifiedEngine) {
    final c = UnifiedEnginePlaybackClient(
      haptics: ref.read(metronomeHapticsProvider),
    );
    ref.onDispose(c.dispose);
    return c;
  }

  final fallback = FlutterMetronomePlaybackClient(
    audioClient: ref.read(metronomeAudioClientProvider),
    hapticsClient: ref.read(metronomeHapticsProvider),
  );
  // Web: the flutter_soloud PCM timeline and the Android platform channel are
  // both unavailable, so drive ticks through the Web Audio scheduler directly.
  if (kIsWeb) {
    ref.onDispose(fallback.dispose);
    return fallback;
  }
  final legacy = PlatformMetronomePlaybackClient(fallback: fallback);
  final client = MetronomeFeatureFlags.enablePcmTimelineEngine
      ? PcmTimelineMetronomePlaybackClient(fallback: legacy)
      : legacy;
  ref.onDispose(client.dispose);
  return client;
});
