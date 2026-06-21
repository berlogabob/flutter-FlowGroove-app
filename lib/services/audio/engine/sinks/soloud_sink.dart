import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';

import '../audio_sink.dart';

/// [AudioSink] implementation backed by `flutter_soloud`'s buffer-stream API.
///
/// Mirrors the buffer-stream usage already proven in
/// `PcmTimelineMetronomePlaybackClient` (see
/// `lib/providers/metronome_runtime_providers.dart`), but implements the
/// `AudioSink` contract (Task 1) and adds [recover], which rebuilds the
/// SoLoud engine and stream from scratch at the current device sample rate.
/// This is the mechanism that survives Bluetooth device switches: SoLoud
/// does not currently expose a way to rebind an existing buffer stream to a
/// new output device, so `recover()` tears the engine down with `deinit()`
/// and re-initializes it, which re-binds to whatever device is now default.
///
/// `pushFrames` converts the renderer's Float32 PCM to 16-bit signed PCM
/// (the format `setBufferStream` defaults to: `BufferType.s16le`) and feeds
/// it via `addAudioDataStream`. Calling `pushFrames` before [open] is a safe
/// no-op so callers don't need to track sink readiness themselves.
class NativeSoLoudSink implements AudioSink {
  final _events = StreamController<SinkEvent>.broadcast();

  AudioSource? _stream;
  SoundHandle? _handle;
  int _sampleRate = 48000;
  int _channels = 1;
  bool _open = false;

  @override
  Stream<SinkEvent> get events => _events.stream;

  /// The sample rate the sink is currently (or was most recently) opened at.
  int get deviceSampleRate => _sampleRate;

  @override
  Future<void> open({required int sampleRate, required int channels}) async {
    _sampleRate = sampleRate;
    _channels = channels;
    try {
      if (!SoLoud.instance.isInitialized) {
        await SoLoud.instance.init(
          sampleRate: sampleRate,
          channels: channels > 1 ? Channels.stereo : Channels.mono,
        );
      }
      _stream = SoLoud.instance.setBufferStream(
        maxBufferSizeDuration: const Duration(seconds: 30),
        // `preserved` keeps already-played data in the buffer instead of
        // freeing it; `released` is the mode that caused permanent silence
        // on underrun (the stream becomes unplayable after it empties out).
        // This matches the API default, but is kept explicit deliberately.
        // ignore: avoid_redundant_argument_values
        bufferingType: BufferingType.preserved,
        bufferingTimeNeeds: 0.1,
        sampleRate: sampleRate,
        channels: channels > 1 ? Channels.stereo : Channels.mono,
      );
      _handle = SoLoud.instance.play(_stream!);
      _open = true;
    } catch (e) {
      _open = false;
      _events.add(SinkEvent(SinkEventType.error, e));
    }
  }

  @override
  void pushFrames(Float32List pcm) {
    if (!_open || _stream == null) return;
    final pcm16 = Int16List(pcm.length);
    for (var i = 0; i < pcm.length; i++) {
      pcm16[i] = (pcm[i].clamp(-1.0, 1.0) * 32767).round();
    }
    try {
      SoLoud.instance.addAudioDataStream(_stream!, pcm16.buffer.asUint8List());
    } catch (e) {
      _events.add(SinkEvent(SinkEventType.error, e));
    }
  }

  @override
  int get framesQueued => 0; // SoLoud manages its own buffer internally.

  @override
  Future<void> recover({required int atFrame}) async {
    _open = false;
    final handle = _handle;
    final stream = _stream;
    _handle = null;
    _stream = null;
    try {
      if (handle != null && SoLoud.instance.isInitialized) {
        await SoLoud.instance.stop(handle);
      }
      if (stream != null && SoLoud.instance.isInitialized) {
        await SoLoud.instance.disposeSource(stream);
      }
      // Re-init at the CURRENT device's native rate. The scheduler re-pumps
      // from `atFrame`, so this sink only needs to rebuild cleanly; it does
      // not replay any audio itself.
      // `deinit()` tears down the SoLoud singleton process-wide, so this sink
      // and the legacy MetronomeAudioEngine must never be active at the same
      // time (deinit() here would yank the audio out from under the other).
      if (SoLoud.instance.isInitialized) {
        SoLoud.instance.deinit();
      }
      await open(sampleRate: _sampleRate, channels: _channels);
      // `open()` swallows its own failures (sets `_open = false` and emits
      // `SinkEventType.error`) instead of throwing, so this await never
      // throws on failure. Only report success to the scheduler when the
      // reopen actually left the sink usable; otherwise the `error` event
      // already emitted by `open()` is the right (and only) signal.
      if (_open) {
        _events.add(const SinkEvent(SinkEventType.deviceChanged));
      }
    } catch (e) {
      _events.add(SinkEvent(SinkEventType.error, e));
    }
  }

  @override
  Future<void> close() async {
    _open = false;
    final handle = _handle;
    final stream = _stream;
    _handle = null;
    _stream = null;
    try {
      if (handle != null && SoLoud.instance.isInitialized) {
        await SoLoud.instance.stop(handle);
      }
      if (stream != null && SoLoud.instance.isInitialized) {
        await SoLoud.instance.disposeSource(stream);
      }
      if (SoLoud.instance.isInitialized) {
        SoLoud.instance.deinit();
      }
    } catch (_) {
      // Best-effort teardown; nothing left to recover into on close().
    }
    await _events.close();
  }
}
