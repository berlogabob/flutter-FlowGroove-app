// Web-only MP3 encoder, wrapping lamejs — see `mp3_encoder.dart` for why.
//
// lamejs is loaded by a <script> tag in web/index.html and lives at
// web/vendor/lamejs.iife.js as a separate, unmodified file. That separation is
// deliberate: it's what satisfies LAME's LGPL relinking condition, so this must
// never be bundled in. See web/vendor/README.md.

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'audio_note_edit.dart';

@JS('lamejs')
external JSObject? get _lamejs;

@JS('lamejs.Mp3Encoder')
extension type _Mp3Encoder._(JSObject _) implements JSObject {
  external _Mp3Encoder(int channels, int sampleRate, int kbps);
  external JSInt16Array encodeBuffer(JSInt16Array samples);
  external JSInt16Array flush();
}

/// True when lamejs actually loaded — a blocked or missing script shouldn't
/// take the share button down with it.
bool get mp3EncoderAvailable => _lamejs != null;

/// Samples per lamejs call. One MPEG frame is 1152 samples; feeding whole
/// frames keeps the encoder from buffering partial ones.
const _samplesPerFrame = 1152;

/// Frames per slice between event-loop yields. ~46ms of encoding per slice at
/// the measured throughput, which keeps a progress spinner animating without
/// paying for a yield on every frame.
const _framesPerSlice = 64;

/// Encodes a mono/stereo 16-bit PCM WAV to MP3 at [kbps].
///
/// Returns null if [wav] isn't PCM WAV or lamejs is unavailable, so callers can
/// fall back to sharing the original bytes rather than nothing.
///
/// Yields to the event loop periodically: a full-length take measures ~2s of
/// solid CPU, which would otherwise freeze the UI mid-share. [onProgress] gets
/// 0..1 for anyone who wants to show it.
Future<Uint8List?> encodeWavToMp3(
  Uint8List wav, {
  int kbps = 128,
  void Function(double progress)? onProgress,
}) async {
  if (!mp3EncoderAvailable) return null;
  final info = parseWav(wav);
  if (info == null || info.bytesPerSample != 2) return null;

  final samples = Int16List.sublistView(
    Uint8List.sublistView(wav, info.offset, info.offset + info.length),
  );
  if (samples.isEmpty) return null;

  // lamejs takes interleaved samples per channel; mono is the common case here
  // and stereo would need deinterleaving, so only mono is claimed.
  if (info.channels != 1) return null;

  final encoder = _Mp3Encoder(info.channels, info.sampleRate, kbps);

  final out = BytesBuilder(copy: false);
  var processed = 0;
  var sinceYield = 0;
  for (var i = 0; i < samples.length; i += _samplesPerFrame) {
    final end = i + _samplesPerFrame < samples.length
        ? i + _samplesPerFrame
        : samples.length;
    final chunk = encoder.encodeBuffer(
      // A view, not a copy — sublistView keeps this allocation-free per frame.
      Int16List.sublistView(samples, i, end).toJS,
    );
    final bytes = chunk.toDart;
    if (bytes.isNotEmpty) out.add(Uint8List.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes));
    processed = end;

    if (++sinceYield >= _framesPerSlice) {
      sinceYield = 0;
      onProgress?.call(processed / samples.length);
      await Future<void>.delayed(Duration.zero);
    }
  }
  final tail = encoder.flush().toDart;
  if (tail.isNotEmpty) {
    out.add(Uint8List.view(tail.buffer, tail.offsetInBytes, tail.lengthInBytes));
  }
  onProgress?.call(1);

  final mp3 = out.takeBytes();
  return mp3.isEmpty ? null : mp3;
}
