/// Offline structure benchmark; ffmpeg must be on PATH. Times are file-relative.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flowgroove/services/audio/song_structure.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.length.isEven) {
    stderr.writeln(
      'Usage: dart run scripts/audio_structure/structure_eval.dart <audio> --bpm <x> --downbeat-ms <ms> [--key <key.txt>]',
    );
    exitCode = 64;
    return;
  }
  final options = <String, String>{};
  for (var i = 1; i < args.length; i += 2) {
    if (!['--bpm', '--downbeat-ms', '--key'].contains(args[i]) ||
        options.containsKey(args[i])) {
      stderr.writeln('Unknown or duplicate option: ${args[i]}');
      exitCode = 64;
      return;
    }
    options[args[i]] = args[i + 1];
  }
  final bpm = double.tryParse(options['--bpm'] ?? '');
  final downbeat = double.tryParse(options['--downbeat-ms'] ?? '');
  if (bpm == null ||
      !bpm.isFinite ||
      bpm <= 0 ||
      downbeat == null ||
      !downbeat.isFinite) {
    stderr.writeln('A positive --bpm and finite --downbeat-ms are required.');
    exitCode = 64;
    return;
  }
  final decoded = await Process.run('ffmpeg', [
    '-v',
    'error',
    '-i',
    args.first,
    '-ac',
    '1',
    '-ar',
    '22050',
    '-f',
    's16le',
    '-',
  ], stdoutEncoding: null);
  if (decoded.exitCode != 0) {
    stderr.write(decoded.stderr);
    exitCode = 1;
    return;
  }
  final bytes = Uint8List.fromList(decoded.stdout as List<int>);
  final data = ByteData.sublistView(bytes);
  final pcm = Int16List(bytes.length ~/ 2);
  for (var i = 0; i < pcm.length; i++) {
    pcm[i] = data.getInt16(i * 2, Endian.little);
  }
  // First downbeat in file time; analyse bars and extend outer regions to
  // the file edges, matching the Lua evaluator.
  final grid = (bpm: bpm, offsetMs: downbeat.round(), barMs: 240000 / bpm);
  final result = analyseStructure(pcm, 22050, grid);
  if (result == null) {
    stderr.writeln('Fewer than eight complete bars.');
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'duration=${(pcm.length / 22050).toStringAsFixed(3)}s bpm=$bpm first downbeat=${downbeat / 1000}s',
  );
  for (var i = 0; i < result.sections.length; i++) {
    final s = result.sections[i];
    final letters = result.parts
        .where((p) => p.sectionIndex == i)
        .map((p) => p.letter)
        .join(' ');
    stdout.writeln(
      '${s.name} [${s.label}] start=${(s.startMs / 1000).toStringAsFixed(3)}s bars=${((s.endMs - s.startMs) / grid.barMs).toStringAsFixed(2)} parts=$letters',
    );
  }
  stdout.writeln(
    'section bars ${result.sections.map((s) => ((s.startMs - downbeat) / grid.barMs).toStringAsFixed(1)).join(', ')}',
  );
  final keyPath = options['--key'];
  if (keyPath != null) {
    final key = <({double time, String name})>[];
    for (final line in const LineSplitter().convert(
      await File(keyPath).readAsString(),
    )) {
      final tab = line.indexOf('\t');
      if (tab < 0) continue;
      final t = double.tryParse(line.substring(0, tab));
      if (t != null) key.add((time: t, name: line.substring(tab + 1)));
    }
    final duration = pcm.length / 22050;
    stdout.writeln(
      'parts ${_score(result.parts.map((p) => p.startMs / 1000), key, duration, sections: false)}',
    );
    stdout.writeln(
      'sections ${_score(result.sections.map((s) => s.startMs / 1000), key, duration, sections: true)}',
    );
  }
}

String _base(String name) {
  final words = name
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  while (words.isNotEmpty && RegExp(r'^([a-z]|[0-9]+)$').hasMatch(words.last)) {
    words.removeLast();
  }
  return words.join(' ');
}

String _score(
  Iterable<double> predicted,
  List<({double time, String name})> key,
  double duration, {
  required bool sections,
}) {
  final truth = <double>[];
  String? previous;
  for (final p in key) {
    final base = _base(p.name);
    if ((!sections || base != previous) &&
        p.time >= 2 &&
        p.time <= duration - 1) {
      truth.add(p.time);
    }
    previous = base;
  }
  final pp = predicted.where((t) => t >= 2 && t <= duration - 1).toList()
    ..sort();
  truth.sort();
  int i = 0;
  int j = 0;
  int hits = 0;
  while (i < pp.length && j < truth.length) {
    if ((pp[i] - truth[j]).abs() <= 1.5) {
      hits++;
      i++;
      j++;
    } else if (pp[i] < truth[j]) {
      i++;
    } else {
      j++;
    }
  }
  double ratio(int a, int b) => a / (b > 0 ? b : 1);
  return 'F=${ratio(2 * hits, pp.length + truth.length).toStringAsFixed(3)} P=${ratio(hits, pp.length).toStringAsFixed(3)} R=${ratio(hits, truth.length).toStringAsFixed(3)} ($hits/${pp.length} predicted, ${truth.length} key)';
}
