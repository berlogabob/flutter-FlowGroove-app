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
  Future<void> dispose() async {
    disposeCalls += 1;
    disposed = true;
  }
}

class FakeMetronomeHapticsClient implements MetronomeHapticsClient {
  int heavyClickCalls = 0;
  int mediumClickCalls = 0;
  int tickCalls = 0;
  int lightImpactCalls = 0;

  @override
  void heavyClick() {
    heavyClickCalls += 1;
  }

  @override
  void mediumClick() {
    mediumClickCalls += 1;
  }

  @override
  void tick() {
    tickCalls += 1;
  }

  @override
  void lightImpact() {
    lightImpactCalls += 1;
  }
}

class FakeMetronomePlaybackClient implements MetronomePlaybackClient {
  int startCalls = 0;
  int updateCalls = 0;
  int resetPhaseCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;

  bool isRunning = false;
  MetronomePlaybackConfig? lastConfig;
  MetronomePlaybackTickCallback? _onTick;
  void Function()? _onStopped;

  @override
  Future<void> start(
    MetronomePlaybackConfig config, {
    required MetronomePlaybackTickCallback onTick,
    void Function()? onStopped,
    int initialTick = -1,
  }) async {
    startCalls += 1;
    isRunning = true;
    lastConfig = config;
    _onTick = onTick;
    _onStopped = onStopped;
  }

  @override
  Future<void> update(MetronomePlaybackConfig config) async {
    updateCalls += 1;
    lastConfig = config;
  }

  @override
  Future<void> resetPhase(MetronomePlaybackConfig config) async {
    resetPhaseCalls += 1;
    lastConfig = config;
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    isRunning = false;
    _onTick = null;
    _onStopped = null;
  }

  @override
  void dispose() {
    disposeCalls += 1;
    isRunning = false;
  }

  void emitTick(int index) {
    final config = lastConfig;
    final onTick = _onTick;
    if (config == null || onTick == null) return;
    onTick(config.tickForIndex(index));
  }

  void emitStopped() {
    _onStopped?.call();
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
    FakeMetronomePlaybackClient? playback,
    FakeWakelockController? wakelock,
  }) : audio = audio ?? FakeMetronomeAudioClient(),
       haptics = haptics ?? FakeMetronomeHapticsClient(),
       playback = playback ?? FakeMetronomePlaybackClient(),
       wakelock = wakelock ?? FakeWakelockController();

  final FakeMetronomeAudioClient audio;
  final FakeMetronomeHapticsClient haptics;
  final FakeMetronomePlaybackClient playback;
  final FakeWakelockController wakelock;

  List<Override> get overrides => <Override>[
    metronomeAudioClientProvider.overrideWithValue(audio),
    metronomeHapticsProvider.overrideWithValue(haptics),
    metronomePlaybackClientProvider.overrideWithValue(playback),
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
