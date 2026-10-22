import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flowgroove/utils/picked_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('readPickedBytes', () {
    test('returns bytes when PlatformFile provides them', () async {
      final file = PlatformFile(
        name: 'a.mid',
        size: 3,
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      final result = await readPickedBytes(file);

      expect(result, Uint8List.fromList([1, 2, 3]));
    });

    test('falls back to readStream when bytes is null', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      final tempFile = await File(
        '${tempDir.path}/a.mid',
      ).writeAsBytes([4, 5, 6], flush: true);
      addTearDown(tempFile.delete);

      final file = PlatformFile(name: 'a.mid', size: 3, path: tempFile.path);

      final result = await readPickedBytes(file);

      expect(result, Uint8List.fromList([4, 5, 6]));
    });
  });
}
