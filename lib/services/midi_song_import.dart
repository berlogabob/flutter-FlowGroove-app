import 'dart:typed_data';

import '../models/midi_song.dart';
import '../models/song_lab.dart';
import 'audio/midi/midi_song_meta_builder.dart';
import 'audio/midi/smf_parser.dart';
import 'audio/midi/smf_song_parser.dart';

class MidiImportPreview {
  const MidiImportPreview({required this.data, required this.meta});

  final MidiSongData data;
  final MidiSongMeta meta;
}

MidiImportPreview previewMidiImport(Uint8List bytes, {MidiSongMeta? previous}) {
  final song = parseSmfSong(bytes);
  return MidiImportPreview(
    data: song,
    meta: buildMidiSongMeta(song, previous: previous),
  );
}

/// Uploads the source file and builds an entry for the caller to persist.
Future<SongLabEntry> saveMidiImport({
  required Uint8List bytes,
  required MidiSongMeta meta,
  required String entryId,
  required String songId,
  required String? bandId,
  required String createdBy,
  required String title,
  required Future<String> Function(
    Uint8List bytes, {
    required String? bandId,
    required String songId,
    required String entryId,
    String ext,
    String contentType,
  })
  upload,
}) async {
  if (bytes.length >= 25 * 1024 * 1024) {
    throw Exception('MIDI file is larger than 25MB');
  }

  Map<String, dynamic>? midi;
  if (meta.tracks.any((track) => track.effectiveRole == MidiRole.drums)) {
    try {
      final pattern = parseDrumSmf(bytes);
      if (pattern.hits.isNotEmpty) midi = pattern.toJson();
    } catch (_) {
      // Legacy compatibility must not prevent importing the full song.
    }
  }

  final url = await upload(
    bytes,
    bandId: bandId,
    songId: songId,
    entryId: entryId,
    ext: 'mid',
    contentType: 'audio/midi',
  );
  final now = DateTime.now();
  return SongLabEntry(
    id: entryId,
    songId: songId,
    bandId: bandId,
    type: LabEntryType.midi,
    title: title,
    authorId: createdBy,
    createdAt: now,
    updatedAt: now,
    midiSong: meta.copyWith(fileUrl: url),
    midi: midi,
  );
}
