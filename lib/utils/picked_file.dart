import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Bytes of a picked file. On Android/iOS `pickFile` returns a path without
/// bytes, and `PlatformFile.readAsBytes()` then throws, so fall back to the
/// byte stream (works on every platform).
Future<Uint8List> readPickedBytes(PlatformFile file) async {
  final bytes = file.bytes;
  if (bytes != null) return bytes;
  final builder = BytesBuilder(copy: false);
  await for (final chunk in file.readAsByteStream()) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}
