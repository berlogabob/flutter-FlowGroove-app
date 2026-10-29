import 'dart:typed_data';

import 'package:flowgroove/services/audio/midi/smf_song_parser.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> _intBytes(int value, int length) => [
  for (var i = length - 1; i >= 0; i--) (value >> (8 * i)) & 255,
];

Uint8List _smf(List<List<int>> tracks, {int? format, int ppq = 480}) =>
    Uint8List.fromList([
      ...'MThd'.codeUnits,
      ..._intBytes(6, 4),
      ..._intBytes(format ?? (tracks.length == 1 ? 0 : 1), 2),
      ..._intBytes(tracks.length, 2),
      ..._intBytes(ppq, 2),
      for (final track in tracks) ...[
        ...'MTrk'.codeUnits,
        ..._intBytes(track.length, 4),
        ...track,
      ],
    ]);

void main() {
  test('format 1 preserves tempo changes and drops the conductor track', () {
    final song = parseSmfSong(
      _smf([
        [
          0,
          0xFF,
          0x51,
          3,
          0x07,
          0xA1,
          0x20,
          0,
          0xFF,
          0x58,
          4,
          4,
          2,
          24,
          8,
          0x83,
          0x60,
          0xFF,
          0x51,
          3,
          0x06,
          0x1A,
          0x80,
          0,
          0xFF,
          0x58,
          4,
          6,
          3,
          24,
          8,
          0,
          0xFF,
          0x2F,
          0,
        ],
        [
          0,
          0xFF,
          0x03,
          5,
          ...'Piano'.codeUnits,
          0,
          0xC0,
          5,
          0,
          0x90,
          60,
          100,
          0x83,
          0x61,
          0x80,
          60,
          64,
          0,
          0xFF,
          0x2F,
          0,
        ],
      ]),
    );

    expect(song.ppq, 480);
    expect(song.initialBpm, 120);
    expect(song.tempos.map((t) => (t.tick, t.microsPerQuarter)), [
      (0, 500000),
      (480, 400000),
    ]);
    expect(song.timeSigs.map((t) => (t.tick, t.numerator, t.denominator)), [
      (0, 4, 4),
      (480, 6, 8),
    ]);
    expect(song.tracks, hasLength(1));
    final track = song.tracks.single;
    expect(
      (track.index, track.name, track.channel, track.program),
      (1, 'Piano', 0, 5),
    );
    expect(track.notes.map((n) => (n.tick, n.dur, n.pitch, n.vel)), [
      (0, 481, 60, 100),
    ]);
  });

  test(
    'running status, velocity-zero off and channels keep separate notes',
    () {
      final song = parseSmfSong(
        _smf([
          [
            0, 0xC0, 4,
            0, 7, // running program change, latest program before first note
            0, 0xC1, 33,
            0, 0xB1, 0, 8, // bank select does not change program
            0, 0x90, 60, 100,
            5, 62, 80,
            5, 60, 0,
            0, 0x91, 60, 90,
            10, 0x81, 60, 0,
            0, 0x80, 62, 0,
            0, 0xC0, 40, // later program cannot change the first note's program
            0, 0xFF, 0x2F, 0,
          ],
        ]),
      );

      expect(song.tracks.map((t) => (t.index, t.name, t.channel, t.program)), [
        (0, 'Track 1', 0, 7),
        (0, 'Track 1', 1, 33),
      ]);
      expect(song.tracks[0].notes.map((n) => (n.tick, n.dur, n.pitch, n.vel)), [
        (0, 10, 60, 100),
        (5, 15, 62, 80),
      ]);
      expect(song.tracks[1].notes.map((n) => (n.tick, n.dur, n.pitch, n.vel)), [
        (10, 10, 60, 90),
      ]);
    },
  );

  test('overlapping same-pitch notes pair FIFO and last until track end', () {
    final song = parseSmfSong(
      _smf([
        [
          0, 0x80, 70, 0, // unmatched off
          0, 0x90, 60, 100,
          5, 60, 90,
          5, 0x80, 60, 0,
          0, 0xF0, 3, 1, 2, 0xF7,
          0, 0xF7, 2, 3, 4,
          0, 0xFF, 0x01, 2, 65, 66, // unknown meta event
          0xCB, 0, 0x90, 64, 80, // tick 9610, beyond four bars
          0, 0x80, 64, 0,
          0, 0x90, 67, 70,
          0, 0xFF, 0x2F, 0,
        ],
      ]),
    );
    expect(song.tracks.single.program, 0);
    expect(song.tracks.single.notes.map((n) => (n.tick, n.dur, n.pitch)), [
      (0, 10, 60),
      (5, 9605, 60),
      (9610, 1, 64),
      (9610, 1, 67),
    ]);
  });

  test(
    'unterminated notes also end at the chunk boundary without end meta',
    () {
      final song = parseSmfSong(
        _smf([
          [0, 0x90, 60, 80, 12, 0xB0, 1, 0],
        ]),
      );
      expect(song.tracks.single.notes.single.dur, 12);
    },
  );

  test('rejects SMPTE, format 2 and invalid headers', () {
    for (final bytes in [
      _smf([[]], ppq: 0xE728),
      _smf([[]], format: 2),
      _smf([[]], ppq: 0),
      Uint8List.fromList([...'BAD!'.codeUnits, 0, 0, 0, 6]),
      Uint8List.fromList([...'MThd'.codeUnits, 0, 0, 0, 5]),
    ]) {
      expect(() => parseSmfSong(bytes), throwsFormatException);
    }
  });

  test('accepts incorrect declared track counts, including format 0', () {
    for (final format in [0, 1]) {
      for (final declaredCount in [0, 1, 3]) {
        final bytes = _smf([
          [0, 0x90, 60, 100],
          [0, 0x91, 64, 100],
        ], format: format)..[11] = declaredCount;
        final song = parseSmfSong(bytes);
        expect(song.tracks.map((t) => t.notes.single.pitch), [60, 64]);
      }
    }
  });

  test('rejects files without MTrk chunks regardless of declared count', () {
    for (final declaredCount in [0, 1]) {
      final bytes = _smf([])..[11] = declaredCount;
      expect(() => parseSmfSong(bytes), throwsFormatException);
      final unknownChunk = Uint8List.fromList([
        ...bytes,
        ...'JUNK'.codeUnits,
        ..._intBytes(0, 4),
      ]);
      expect(() => parseSmfSong(unknownChunk), throwsFormatException);
    }
  });

  test('accepts 200000 total notes and rejects the next note', () {
    for (final closeNotes in [false, true]) {
      final events = <int>[
        for (var i = 0; i < 100000; i++) ...[
          0,
          0x90,
          60,
          100,
          if (closeNotes) ...[1, 0x80, 60, 0],
        ],
      ];
      final song = parseSmfSong(_smf([events, events]));
      expect(song.tracks.fold<int>(0, (n, t) => n + t.notes.length), 200000);
      expect(
        () => parseSmfSong(
          _smf([
            events,
            [...events, 0, 0x91, 64, 100],
          ]),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'Too many notes',
          ),
        ),
      );
    }
  });

  test('accepts 64 resulting channel tracks and rejects the next track', () {
    final tracks = List.generate(
      4,
      (_) => <int>[
        for (var channel = 0; channel < 16; channel++) ...[
          0,
          0x90 | channel,
          60,
          100,
        ],
      ],
    );
    expect(parseSmfSong(_smf(tracks)).tracks, hasLength(64));
    expect(
      () => parseSmfSong(
        _smf([
          ...tracks,
          [0, 0x90, 60, 100],
        ]),
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'Too many tracks',
        ),
      ),
    );
    expect(
      parseSmfSong(_smf(List.generate(65, (_) => <int>[]))).tracks,
      isEmpty,
    );
  });

  test('truncations throughout a valid file throw FormatException', () {
    final bytes = _smf([
      [0, 0x90, 60, 100, 10, 0x80, 60, 0, 0, 0xFF, 0x2F, 0],
    ]);
    for (var length = 0; length < bytes.length; length++) {
      expect(
        () => parseSmfSong(Uint8List.sublistView(bytes, 0, length)),
        throwsFormatException,
        reason: 'truncated at byte $length',
      );
    }
  });

  test('rejects malformed events within complete chunks', () {
    for (final events in <List<int>>[
      [0, 60, 100], // no running status
      [0, 0x90, 60], // incomplete note
      [0, 0x90, 60, 0x80], // invalid data byte
      [0x81, 0x80, 0x80, 0x80, 0], // overlong delta
      [0, 0xF0, 2, 1], // incomplete sysex
      [0, 0xFF, 0x51, 2, 1, 2],
      [0, 0xFF, 0x58, 3, 4, 2, 24],
      [0, 0xFF, 0x2F, 1, 0],
      [0, 0xF1, 0], // unsupported status
      [0, 0xC0, 1, 0, 0xFF, 1, 0, 0, 2], // meta clears status
      [0, 0xC0, 1, 0, 0xF7, 0, 0, 2], // sysex clears status
    ]) {
      expect(() => parseSmfSong(_smf([events])), throwsFormatException);
    }
  });
}
