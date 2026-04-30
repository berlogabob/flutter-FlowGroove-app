import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/audio/audio_engine_export.dart';

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

  void dispose();
}

class AudioEngineMetronomeAudioClient implements MetronomeAudioClient {
  AudioEngineMetronomeAudioClient({AudioEngine? engine}) : _engine = engine;

  AudioEngine? _engine;

  AudioEngine get _audioEngine => _engine ??= AudioEngine();

  @override
  Future<void> initialize() {
    return _audioEngine.initialize();
  }

  @override
  Future<void> preWarmPlayers() {
    return _audioEngine.preWarmPlayers();
  }

  @override
  Future<void> playClick({
    required bool isAccent,
    required String waveType,
    required double volume,
    double? accentFrequency,
    double? beatFrequency,
  }) {
    return _audioEngine.playClick(
      isAccent: isAccent,
      waveType: waveType,
      volume: volume,
      accentFrequency: accentFrequency,
      beatFrequency: beatFrequency,
    );
  }

  @override
  Future<void> playTest() {
    return _audioEngine.playTest();
  }

  @override
  void dispose() {
    _engine?.dispose();
    _engine = null;
  }
}

abstract class MetronomeHapticsClient {
  void lightImpact();
}

class SystemMetronomeHapticsClient implements MetronomeHapticsClient {
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
