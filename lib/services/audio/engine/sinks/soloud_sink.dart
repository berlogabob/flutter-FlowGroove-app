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
  int _pushedFrames = 0;
  bool _open = false;

  @override
  Stream<SinkEvent> get events => _events.stream;

  /// The sample rate the sink is currently (or was most recently) opened at.
  int get deviceSampleRate => _sampleRate;

  /// Push a `deviceChanged` event onto [events] so an external observer (e.g.
  /// [AudioRouteMonitor] surfacing a Bluetooth/wired switch) can trigger the
  /// scheduler's recovery path, which calls [recover] to rebuild the engine on
  /// the new default device. Kept minimal: this only signals; the scheduler
  /// owns the actual recover() call.
  void signalDeviceChanged() =>
      _events.add(const SinkEvent(SinkEventType.deviceChanged));

  @override
  Future<void> open({required int sampleRate, required int channels}) async {
    _sampleRate = sampleRate;
    _channels = channels;
    // A new stream restarts SoLoud's consumed-time counter at 0.
    _pushedFrames = 0;
    try {
      if (!SoLoud.instance.isInitialized) {
        await SoLoud.instance.init(
          sampleRate: sampleRate,
          channels: channels > 1 ? Channels.stereo : Channels.mono,
        );
      }
      _stream = SoLoud.instance.setBufferStream(
        maxBufferSizeDuration: const Duration(seconds: 30),
        // `released` frees already-played samples so the buffer stays bounded
        // for indefinite playback. `preserved` accumulates every played sample
        // and hits maxBufferSizeDuration after ~30s, stopping the metronome
        // (~60 beats at 120 BPM). The underrun-on-route-change case that once
        // motivated `preserved` is now handled by explicit device-change
        // recovery (AudioRouteMonitor -> signalDeviceChanged -> recover()).
        bufferingType: BufferingType.released,
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
      _pushedFrames += pcm.length ~/ _channels;
    } catch (e) {
      _events.add(SinkEvent(SinkEventType.error, e));
    }
  }

  @override
  int get framesQueued {
    if (!_open || _stream == null) return 0;
    try {
      // RELEASED-buffer-only API — this sink always uses BufferingType.released
      // (see open()). It throws if that ever changes, or if SoLoud is torn
      // down mid-call, so swallow: 0 means "unknown" and nothing gates on it.
      final consumed = SoLoud.instance.getStreamTimeConsumed(_stream!);
      final consumedFrames = consumed.inMicroseconds * _sampleRate ~/ 1000000;
      final queued = _pushedFrames - consumedFrames;
      return queued > 0 ? queued : 0;
    } on Object {
      return 0;
    }
  }

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
        // `recovered`, NOT `deviceChanged`: the scheduler answers
        // `deviceChanged` by recovering, so emitting it on success made
        // recovery re-enter itself forever — each cycle a process-wide
        // deinit()+init() with the feeder disabled throughout (#151).
        _events.add(const SinkEvent(SinkEventType.recovered));
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
