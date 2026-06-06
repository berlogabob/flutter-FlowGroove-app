import 'dart:async';

import 'package:flutter/foundation.dart'
    show
        TargetPlatform,
        VoidCallback,
        debugPrint,
        defaultTargetPlatform,
        kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/beat_mode.dart';
import '../models/metronome_state.dart';
import '../services/audio/metronome_audio_engine.dart';
import '../services/audio/wall_clock_scheduler.dart';

abstract class MetronomeAudioClient {
  Future<void> initialize();

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
  final client = AudioEngineMetronomeAudioClient();
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
  });

  final int index;
  final int beatIndex;
  final int subdivisionIndex;
  final bool isMainBeat;
  final bool shouldPlay;
  final double frequency;
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
    required this.hapticsEnabled,
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
      hapticsEnabled: state.hapticsEnabled,
    );
  }

  final int bpm;
  final int accentBeats;
  final int regularBeats;
  final List<List<BeatMode>> beatModes;
  final String waveType;
  final double volume;
  final bool accentEnabled;
  final double accentFrequency;
  final double beatFrequency;
  final bool hapticsEnabled;

  int get _safeAccentBeats => accentBeats.clamp(1, 12);

  int get _safeRegularBeats => regularBeats.clamp(1, 12);

  int get totalTicks => _safeAccentBeats * _safeRegularBeats;

  Duration get interval {
    final micros = (60000000 / bpm.clamp(10, 260) / _safeRegularBeats)
        .round()
        .clamp(1000, 1500000);
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
    final baseFrequency = isMainBeat && accentEnabled
        ? accentFrequency
        : beatFrequency;
    final frequency = mode == BeatMode.accent
        ? baseFrequency + 300.0
        : baseFrequency;

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

  Future<void> stop();

  void dispose();
}

class FlutterMetronomePlaybackClient implements MetronomePlaybackClient {
  FlutterMetronomePlaybackClient({
    required MetronomeAudioClient audioClient,
    required MetronomeHapticsClient hapticsClient,
  }) : _audioClient = audioClient,
       _hapticsClient = hapticsClient;

  final MetronomeAudioClient _audioClient;
  final MetronomeHapticsClient _hapticsClient;

  final WallClockScheduler _scheduler = WallClockScheduler();
  MetronomePlaybackConfig? _config;
  MetronomePlaybackTickCallback? _onTick;
  int _tickIndex = -1;

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
    _scheduler.start(config.interval, _handleTick);
  }

  @override
  Future<void> update(MetronomePlaybackConfig config) async {
    _config = config;
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
  }

  void _handleTick() {
    try {
      final config = _config;
      final onTick = _onTick;
      if (config == null || onTick == null) return;

      _tickIndex = (_tickIndex + 1) % config.totalTicks;
      final tick = config.tickForIndex(_tickIndex);

      if (tick.shouldPlay) {
        if (config.hapticsEnabled) {
          final beatIndex = tick.beatIndex;
          final subdivisionIndex = tick.subdivisionIndex;
          if (subdivisionIndex > 0) {
            _hapticsClient.tick();
          } else {
            final mode = (beatIndex < config.beatModes.length &&
                    subdivisionIndex < config.beatModes[beatIndex].length)
                ? config.beatModes[beatIndex][subdivisionIndex]
                : BeatMode.normal;
            switch (mode) {
              case BeatMode.accent:
                _hapticsClient.heavyClick();
              case BeatMode.normal:
                _hapticsClient.mediumClick();
              case BeatMode.silent:
                // No haptic for silent beats
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
    } catch (error, stackTrace) {
      debugPrint('[MetronomePlayback] tick error: $error\n$stackTrace');
    }
  }
}

class PlatformMetronomePlaybackClient implements MetronomePlaybackClient {
  PlatformMetronomePlaybackClient({
    required FlutterMetronomePlaybackClient fallback,
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel('com.flowgroove/metronome'),
       _fallback = fallback {
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

final metronomePlaybackClientProvider = Provider<MetronomePlaybackClient>((
  ref,
) {
  final fallback = FlutterMetronomePlaybackClient(
    audioClient: ref.read(metronomeAudioClientProvider),
    hapticsClient: ref.read(metronomeHapticsProvider),
  );
  final client = PlatformMetronomePlaybackClient(fallback: fallback);
  ref.onDispose(client.dispose);
  return client;
});
