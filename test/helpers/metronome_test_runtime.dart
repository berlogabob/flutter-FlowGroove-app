import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/providers/metronome_runtime_providers.dart';
import 'package:flowgroove/providers/wakelock_provider.dart';
import 'package:flowgroove/services/wakelock_controller.dart';

class FakeMetronomeAudioClient implements MetronomeAudioClient {
  int initializeCalls = 0;
  int preWarmPlayersCalls = 0;
  int playClickCalls = 0;
  int playTestCalls = 0;
  int disposeCalls = 0;

  bool initialized = false;
  bool disposed = false;

  bool shouldThrowOnInitialize = false;
  bool shouldThrowOnPlayClick = false;
  bool shouldThrowOnPlayTest = false;

  @override
  Future<void> initialize() async {
    initializeCalls += 1;
    if (shouldThrowOnInitialize) {
      throw StateError('audio initialize failed');
    }
    initialized = true;
  }

  @override
  Future<void> preWarmPlayers() async {
    preWarmPlayersCalls += 1;
  }

  @override
  Future<void> playClick({
    required bool isAccent,
    required String waveType,
    required double volume,
    double? accentFrequency,
    double? beatFrequency,
  }) async {
    playClickCalls += 1;
    if (shouldThrowOnPlayClick) {
      throw StateError('audio playClick failed');
    }
  }

  @override
  Future<void> playTest() async {
    playTestCalls += 1;
    if (shouldThrowOnPlayTest) {
      throw StateError('audio playTest failed');
    }
  }

  @override
  void dispose() {
    disposeCalls += 1;
    disposed = true;
  }
}

class FakeMetronomeHapticsClient implements MetronomeHapticsClient {
  int lightImpactCalls = 0;

  @override
  void lightImpact() {
    lightImpactCalls += 1;
  }
}

class FakeWakelockController extends WakelockController {
  int enableCalls = 0;
  int disableCalls = 0;
  int disposeCalls = 0;

  bool _enabled = false;
  bool _disposed = false;

  @override
  bool get isEnabled => _enabled;

  @override
  bool get isDisposed => _disposed;

  @override
  Future<bool> enable() async {
    enableCalls += 1;
    if (_disposed) {
      return false;
    }
    _enabled = true;
    return true;
  }

  @override
  Future<bool> disable() async {
    disableCalls += 1;
    if (_disposed) {
      return false;
    }
    _enabled = false;
    return true;
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
    _enabled = false;
    _disposed = true;
  }
}

class MetronomeTestRuntime {
  MetronomeTestRuntime({
    FakeMetronomeAudioClient? audio,
    FakeMetronomeHapticsClient? haptics,
    FakeWakelockController? wakelock,
  }) : audio = audio ?? FakeMetronomeAudioClient(),
       haptics = haptics ?? FakeMetronomeHapticsClient(),
       wakelock = wakelock ?? FakeWakelockController();

  final FakeMetronomeAudioClient audio;
  final FakeMetronomeHapticsClient haptics;
  final FakeWakelockController wakelock;

  List<Override> get overrides => <Override>[
    metronomeAudioClientProvider.overrideWithValue(audio),
    metronomeHapticsProvider.overrideWithValue(haptics),
    wakelockProvider.overrideWithValue(wakelock),
  ];

  Future<void> dispose() async {
    await wakelock.dispose();
  }
}

List<Override> buildMetronomeTestOverrides({
  MetronomeTestRuntime? runtime,
  bool overrideMetronomeProvider = false,
}) {
  final testRuntime = runtime ?? MetronomeTestRuntime();

  return <Override>[
    ...testRuntime.overrides,
    if (overrideMetronomeProvider)
      metronomeProvider.overrideWith(MetronomeNotifier.new),
  ];
}
