import 'dart:async';
import 'audio_sink.dart';
import 'pcm_click_renderer.dart';
import 'render_config.dart';

class MetronomeScheduler {
  MetronomeScheduler({
    required AudioSink sink,
    required PcmClickRenderer renderer,
    this.chunk = const Duration(milliseconds: 200),
    int sampleRate = 48000,
    bool testMode = false,
  })  : _sink = sink,
        _renderer = renderer,
        _sampleRate = sampleRate,
        _testMode = testMode {
    _sub = _sink.events.listen(_onSinkEvent);
  }

  final AudioSink _sink;
  final PcmClickRenderer _renderer;
  final Duration chunk;
  final int _sampleRate;
  final bool _testMode;

  late final StreamSubscription<SinkEvent> _sub;
  RenderConfig? _config;
  int _frame = 0;
  bool _running = false;
  bool _recovering = false;
  Timer? _pump;

  /// Look-ahead chunks primed at start so a late pump can't underrun the
  /// released buffer stream (3 * chunk = ~600ms at the 200ms default).
  static const int _primeChunks = 3;

  int get currentFrame => _frame;
  int get _chunkFrames => (_sampleRate * chunk.inMilliseconds / 1000).round();

  Future<void> start(RenderConfig config) async {
    _config = config;
    _frame = 0;
    _running = true;
    await _sink.open(sampleRate: _sampleRate, channels: 1);
    if (!_testMode) {
      _pump = Timer.periodic(chunk, (_) => _pumpOnce());
      // Prime several chunks of look-ahead so a late timer tick (GC/jank)
      // can't underrun the released buffer stream and end playback. With the
      // released buffer this stays bounded (~_primeChunks ahead) in steady state.
      for (var i = 0; i < _primeChunks; i++) {
        _pumpOnce();
      }
    }
  }

  void update(RenderConfig config) => _config = config;

  void _pumpOnce() {
    if (!_running || _recovering) return;
    final c = _config;
    if (c == null) return;
    final frames = _renderer.renderChunk(
        config: c, startFrame: _frame, frameCount: _chunkFrames);
    _sink.pushFrames(frames);
    _frame += _chunkFrames;
  }

  /// Test seam: deterministic single pump (no real timer).
  void pumpForTest() => _pumpOnce();

  Future<void> _onSinkEvent(SinkEvent e) async {
    switch (e.type) {
      case SinkEventType.deviceChanged:
      case SinkEventType.error:
        _recovering = true;
        await _sink.recover(atFrame: _frame);
        _recovering = false;
      case SinkEventType.underrun:
        _pumpOnce();
      case SinkEventType.focusLost:
      case SinkEventType.focusGained:
        break;
    }
  }

  Future<void> stop() async {
    _running = false;
    _pump?.cancel();
    await _sub.cancel();
    await _sink.close();
  }
}
