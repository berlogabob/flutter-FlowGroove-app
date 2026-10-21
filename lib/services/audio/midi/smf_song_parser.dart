import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import '../../../models/midi_song.dart';
import 'smf_parser.dart';

/// Parses a song using the program active at each channel's first note for its
/// track; later program changes are ignored.
MidiSongData parseSmfSong(Uint8List bytes) {
  final reader = SmfReader(bytes);
  if (reader.readInt(4) != 0x4D546864) {
    throw const FormatException('Missing MThd header');
  }
  final headerLength = reader.readInt(4);
  if (headerLength < 6) {
    throw const FormatException('Invalid MThd length');
  }
  final header = reader.readChunk(headerLength);
  final format = header.readInt(2);
  header.readInt(2); // Real files may declare an incorrect track count.
  final ppq = header.readInt(2);
  if (format > 1 || ppq == 0 || (ppq & 0x8000) != 0) {
    throw const FormatException('Unsupported MIDI header');
  }

  final tempos = <TempoChange>[];
  final timeSigs = <TimeSigChange>[];
  final markers = <({int tick, String text})>[];
  final tracks = <MidiTrackData>[];
  var tracksRead = 0;
  var noteCount = 0;
  while (!reader.isAtEnd) {
    final chunkType = reader.readInt(4);
    final track = reader.readChunk(reader.readInt(4));
    if (chunkType != 0x4D54726B) continue;
    final index = tracksRead++;
    var name = 'Track ${index + 1}';
    var tick = 0;
    var runningStatus = 0;
    final programs = List<int>.filled(16, 0);
    final notePrograms = <int, int>{};
    final notes = <int, List<MidiNote>>{};
    final active = <(int, int), Queue<({int tick, int vel})>>{};

    void finishNote(int channel, int pitch, {bool all = false}) {
      final pending = active[(channel, pitch)];
      if (pending == null) return;
      while (pending.isNotEmpty) {
        final start = pending.removeFirst();
        notes[channel]!.add(
          MidiNote(
            tick: start.tick,
            dur: tick > start.tick ? tick - start.tick : 1,
            pitch: pitch,
            vel: start.vel,
          ),
        );
        if (!all) break;
      }
    }

    while (!track.isAtEnd) {
      tick += track.readVariableLength();
      var status = track.readInt(1);
      int? firstData;
      if (status < 0x80) {
        if (runningStatus == 0) {
          throw const FormatException('Missing running status');
        }
        firstData = status;
        status = runningStatus;
      }
      if (status == 0xFF) {
        runningStatus = 0;
        final type = track.readDataByte();
        final length = track.readVariableLength();
        final data = track.readChunk(length);
        if (type == 0x51) {
          if (length != 3) {
            throw const FormatException('Invalid tempo length');
          }
          final tempo = data.readInt(3);
          if (tempo == 0) throw const FormatException('Invalid tempo');
          tempos.add(TempoChange(tick: tick, microsPerQuarter: tempo));
        } else if (type == 0x58) {
          if (length != 4) {
            throw const FormatException('Invalid time signature length');
          }
          final numerator = data.readInt(1);
          final exponent = data.readInt(1);
          // Dart integers cannot represent a positive denominator above 2^62.
          if (numerator == 0 || exponent > 62) {
            throw const FormatException('Invalid time signature');
          }
          timeSigs.add(
            TimeSigChange(
              tick: tick,
              numerator: numerator,
              denominator: 1 << exponent,
            ),
          );
        } else if (type == 0x06 || type == 0x07) {
          markers.add((
            tick: tick,
            text: utf8.decode(data.bytes, allowMalformed: true),
          ));
        } else if (type == 0x03) {
          final trackName = utf8.decode(data.bytes, allowMalformed: true);
          if (trackName.isNotEmpty) name = trackName;
        } else if (type == 0x2F) {
          if (length != 0) {
            throw const FormatException('Invalid end-of-track length');
          }
          break;
        }
      } else if (status == 0xF0 || status == 0xF7) {
        runningStatus = 0;
        track.skip(track.readVariableLength());
      } else if (status >= 0x80 && status <= 0xEF) {
        runningStatus = status;
        final channel = status & 0x0F;
        final type = status & 0xF0;
        final data1 = firstData ?? track.readDataByte();
        final data2 = type == 0xC0 || type == 0xD0 ? 0 : track.readDataByte();
        if (type == 0xC0) {
          programs[channel] = data1;
        } else if (type == 0x90 && data2 > 0) {
          if (++noteCount > 200000) {
            throw const FormatException('Too many notes');
          }
          // The model stores one program per channel track, at its first note.
          notePrograms.putIfAbsent(channel, () => programs[channel]);
          notes.putIfAbsent(channel, () => <MidiNote>[]);
          active.putIfAbsent((channel, data1), Queue.new).add((
            tick: tick,
            vel: data2,
          ));
        } else if (type == 0x80 || (type == 0x90 && data2 == 0)) {
          finishNote(channel, data1);
        }
      } else {
        throw const FormatException('Invalid MIDI event status');
      }
    }
    for (final key in active.keys) {
      finishNote(key.$1, key.$2, all: true);
    }
    final channels = notes.keys.toList()..sort();
    for (final channel in channels) {
      if (tracks.length >= 64) {
        throw const FormatException('Too many tracks');
      }
      final channelNotes = notes[channel]!
        ..sort((a, b) => a.tick.compareTo(b.tick));
      tracks.add(
        MidiTrackData(
          index: index,
          name: name,
          channel: channel,
          program: notePrograms[channel]!,
          notes: channelNotes,
        ),
      );
    }
  }
  if (tracksRead == 0) {
    throw const FormatException('Missing MTrk chunk');
  }
  tempos.sort((a, b) => a.tick.compareTo(b.tick));
  timeSigs.sort((a, b) => a.tick.compareTo(b.tick));
  markers.sort((a, b) => a.tick.compareTo(b.tick));
  return MidiSongData(
    ppq: ppq,
    tempos: tempos,
    timeSigs: timeSigs,
    tracks: tracks,
    markers: markers,
  );
}
