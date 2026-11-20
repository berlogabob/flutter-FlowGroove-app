/// Manual check, not part of the suite: no-hint BPM of real songs (ffmpeg on PATH).
/// BPM_FILES="a.wav:b.mp3" flutter test scripts/audio_structure/bpm_check_test.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flowgroove/services/audio/audio_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final files = (Platform.environment['BPM_FILES'] ?? '').split(':').where((f) => f.isNotEmpty);
  test('no-hint bpm', () async {
    for (final f in files) {
      final r = await Process.run('ffmpeg', ['-v', 'quiet', '-i', f, '-f', 's16le', '-ac', '1', '-ar', '22050', '-'],
          stdoutEncoding: null);
      final bytes = Uint8List.fromList(r.stdout as List<int>);
      final g = estimateGrid(bytes.buffer.asInt16List(0, bytes.length ~/ 2), 22050);
      // ignore: avoid_print
      print('BPM ${g?.bpm} ${f.split('/').last}');
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
