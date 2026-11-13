import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Bytes of a picked file. Fall back to the byte stream when the picker
/// provides a path without bytes.
Future<Uint8List> readPickedBytes(PlatformFile file) async {
  try {
    return await file.readAsBytes();
  } on StateError {
    // Path-only files are read from the stream below.
  }
  final builder = BytesBuilder(copy: false);
  await for (final chunk in file.readAsByteStream()) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}
