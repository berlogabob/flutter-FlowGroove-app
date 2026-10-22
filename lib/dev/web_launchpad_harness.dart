// Dev-only entry point (flutter build web -t lib/dev/web_launchpad_harness.dart).
// Runs the real launchpad, transport and web audio engine on a synthetic MIDI
// song, with no login or backend, so a browser test can verify how the web
// engine schedules stems against the click clock. Not part of the app.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/section.dart';
import '../models/song_lab.dart';
import '../providers/data/midi_song_provider.dart';
import '../services/audio/midi/midi_song_meta_builder.dart';
import '../services/audio/midi/smf_song_parser.dart';
import '../widgets/practice/launchpad_view.dart';

List<int> _int(int value, int length) => [
  for (var i = length - 1; i >= 0; i--) (value >> (8 * i)) & 255,
];

List<int> _vlq(int value) {
  final out = <int>[value & 0x7F];
  var rest = value >> 7;
  while (rest > 0) {
    out.insert(0, (rest & 0x7F) | 0x80);
    rest >>= 7;
  }
  return out;
}

List<int> _track(List<(int, List<int>)> events) {
  events.sort((a, b) => a.$1.compareTo(b.$1));
  final body = <int>[];
  var last = 0;
  for (final (tick, bytes) in events) {
    body
      ..addAll(_vlq(tick - last))
      ..addAll(bytes);
    last = tick;
  }
  body.addAll([0, 0xFF, 0x2F, 0]);
  return [...'MTrk'.codeUnits, ..._int(body.length, 4), ...body];
}

/// 8 bars of 4/4 at 123 BPM: a bass line and a kick/snare pattern.
Uint8List buildHarnessSmf() {
  const ppq = 480;
  const micros = 487805;
  final conductor = _track([
    (0, [0xFF, 0x51, 3, ..._int(micros, 3)]),
    (0, [0xFF, 0x58, 4, 4, 2, 24, 8]),
  ]);
  final bass = <(int, List<int>)>[
    (0, [0xC0, 33]),
  ];
  final drums = <(int, List<int>)>[];
  for (var beat = 0; beat < 32; beat++) {
    final tick = beat * ppq;
    bass
      ..add((tick, [0x90, 36 + (beat % 4) * 2, 90]))
      ..add((tick + 240, [0x80, 36 + (beat % 4) * 2, 0]));
    final drum = beat.isEven ? 36 : 38;
    drums
      ..add((tick, [0x99, drum, 100]))
      ..add((tick + 120, [0x89, drum, 0]));
  }
  return Uint8List.fromList([
    ...'MThd'.codeUnits,
    ..._int(6, 4),
    ..._int(1, 2),
    ..._int(3, 2),
    ..._int(ppq, 2),
    ...conductor,
    ..._track(bass),
    ..._track(drums),
  ]);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final bytes = buildHarnessSmf();
  final meta = buildMidiSongMeta(
    parseSmfSong(bytes),
    fileUrl: 'harness://song.mid',
  );
  final entry = SongLabEntry(
    id: 'harness-entry',
    songId: 'harness-song',
    type: LabEntryType.midi,
    authorId: 'harness',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    midiSong: meta,
  );
  runApp(
    ProviderScope(
      overrides: [
        midiSongBytesFetcherProvider.overrideWithValue((_) async => bytes),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: SafeArea(
            child: LaunchpadView(
              entry: entry,
              sections: [
                Section(id: 's1', name: 'Intro', duration: 1),
                Section(id: 's2', name: 'Verse', duration: 1),
                Section(id: 's3', name: 'Chorus', duration: 1),
                Section(id: 's4', name: 'Outro', duration: 1),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
