import 'dart:typed_data';

import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/services/audio/midi/smf_parser.dart';
import 'package:flowgroove/services/midi_song_import.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List smf({int channel = 0, int trackCount = 1, String? name}) {
  final track = [
    if (name != null) ...[0, 0xff, 3, name.length, ...name.codeUnits],
    0,
    0x90 | channel,
    36,
    100,
    96,
    0x80 | channel,
    36,
    0,
    0,
    0xff,
    0x2f,
    0,
  ];
  return Uint8List.fromList([
    ...'MThd'.codeUnits,
    0,
    0,
    0,
    6,
    0,
    1,
    0,
    trackCount,
    0,
    96,
    ...'MTrk'.codeUnits,
    0,
    0,
    0,
    track.length,
    ...track,
  ]);
}

void main() {
  const url = 'https://example.com/song.mid';
  late int uploads;
  late Uint8List uploadedBytes;
  late Map<String, Object?> uploadOptions;

  Future<String> upload(
    Uint8List bytes, {
    required String? bandId,
    required String songId,
    required String entryId,
    String ext = 'm4a',
    String contentType = 'audio/mp4',
  }) async {
    uploads++;
    uploadedBytes = bytes;
    uploadOptions = {
      'bandId': bandId,
      'songId': songId,
      'entryId': entryId,
      'ext': ext,
      'contentType': contentType,
    };
    return url;
  }

  Future<SongLabEntry> import(
    Uint8List bytes, {
    String? bandId = 'band',
    MidiSongMeta? meta,
  }) => saveMidiImport(
    bytes: bytes,
    meta: meta ?? previewMidiImport(bytes).meta,
    entryId: 'entry',
    songId: 'song',
    bandId: bandId,
    createdBy: 'author',
    title: 'Song.mid',
    upload: upload,
  );

  setUp(() => uploads = 0);

  test('parses song data and builds metadata without uploading', () {
    final parsed = previewMidiImport(smf(channel: 9));
    expect(parsed.data.ppq, 96);
    expect(parsed.data.tracks.single.notes.single.dur, 96);
    expect(parsed.meta.ppq, parsed.data.ppq);
    expect(parsed.meta.initialBpm, parsed.data.initialBpm);
    expect(parsed.meta.tracks.single.effectiveRole, MidiRole.drums);
    expect(parsed.meta.fileUrl, isNull);
    expect(uploads, 0);
  });

  test('uploads MIDI and stores its URL and entry fields', () async {
    final bytes = smf();
    final entry = await import(bytes);
    expect(uploads, 1);
    expect(uploadedBytes, same(bytes));
    expect(uploadOptions, {
      'bandId': 'band',
      'songId': 'song',
      'entryId': 'entry',
      'ext': 'mid',
      'contentType': 'audio/midi',
    });
    expect(entry.id, 'entry');
    expect(entry.songId, 'song');
    expect(entry.bandId, 'band');
    expect(entry.authorId, 'author');
    expect(entry.title, 'Song.mid');
    expect(entry.type, LabEntryType.midi);
    expect(entry.createdAt, entry.updatedAt);
    expect(entry.midiSong!.fileUrl, url);
    final storedMeta = entry.toJson()['midiSong'] as Map<String, dynamic>;
    expect(storedMeta['fileUrl'], url);
  });

  for (final size in [25 * 1024 * 1024, 25 * 1024 * 1024 + 1]) {
    test('rejects $size bytes before parsing or uploading', () async {
      await expectLater(
        import(Uint8List(size), meta: previewMidiImport(smf()).meta),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            'Exception: MIDI file is larger than 25MB',
          ),
        ),
      );
      expect(uploads, 0);
    });
  }

  test('drum file includes the existing legacy drum pattern', () async {
    final bytes = smf(channel: 9);
    final entry = await import(bytes);
    expect(entry.midi, parseDrumSmf(bytes).toJson());
    expect(entry.pattern!.hits.single.note, 36);
  });

  test('preserves previous settings and uses the effective role', () async {
    final bytes = smf(channel: 9);
    final original = previewMidiImport(bytes).meta;
    final previous = original.copyWith(
      tracks: [
        original.tracks.single.copyWith(
          roleOverride: MidiRole.bass,
          mute: true,
          volume: 0.5,
        ),
      ],
    );
    final preview = previewMidiImport(bytes, previous: previous);
    final entry = await import(bytes, meta: preview.meta);
    final track = entry.midiSong!.tracks.single;
    expect(track.detectedRole, MidiRole.drums);
    expect(track.effectiveRole, MidiRole.bass);
    expect(track.mute, isTrue);
    expect(track.volume, 0.5);
    expect(entry.midi, isNull);
    expect(preview.meta.fileUrl, isNull);
    expect(entry.midiSong!.fileUrl, url);
  });

  test('non-drum file leaves legacy MIDI null', () async {
    final entry = await import(smf(), bandId: null);
    expect(entry.midiSong!.tracks.single.effectiveRole, MidiRole.bass);
    expect(entry.midi, isNull);
    expect(entry.toJson().containsKey('midi'), isFalse);
    expect(entry.bandId, isNull);
    expect(uploadOptions['bandId'], isNull);
  });

  test('drums-role track without legacy hits leaves MIDI null', () async {
    final entry = await import(smf(name: 'Drums'));
    expect(entry.midiSong!.tracks.single.effectiveRole, MidiRole.drums);
    expect(entry.midi, isNull);
    expect(entry.midiSong!.fileUrl, url);
  });

  test('legacy parser failure still imports the full song', () async {
    final bytes = smf(channel: 9, trackCount: 2);
    expect(() => parseDrumSmf(bytes), throwsFormatException);
    final entry = await import(bytes);
    expect(entry.midiSong!.tracks.single.effectiveRole, MidiRole.drums);
    expect(entry.midiSong!.fileUrl, url);
    expect(entry.midi, isNull);
  });

  test('invalid MIDI fails before uploading', () async {
    expect(() => previewMidiImport(Uint8List(4)), throwsFormatException);
    expect(uploads, 0);
  });
}
