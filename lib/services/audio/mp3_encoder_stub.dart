import 'dart:typed_data';

/// Native stub — see `mp3_encoder.dart`.
///
/// Native records AAC and shares `.m4a`, so it never needs an MP3 encoder.
/// Returning null makes callers fall through to sharing the original bytes.
Future<Uint8List?> encodeWavToMp3(
  Uint8List wav, {
  int kbps = 128,
  void Function(double progress)? onProgress,
}) async => null;

/// Whether an MP3 encoder is available on this platform. Always false natively.
bool get mp3EncoderAvailable => false;
