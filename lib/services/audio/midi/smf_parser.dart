import 'dart:typed_data';

import '../../../models/midi_pattern.dart';

MidiPattern parseDrumSmf(
  Uint8List bytes, {
  int maxBars = 4,
  int stepsPerBeat = 4,
}) {
  if (maxBars < 1 || stepsPerBeat < 1) {
    throw ArgumentError('maxBars and stepsPerBeat must be positive');
  }

  final reader = _SmfReader(bytes);
  if (reader.readInt(4) != 0x4D546864) {
    throw const FormatException('Missing MThd header');
  }
  final headerLength = reader.readInt(4);
  if (headerLength < 6) {
    throw const FormatException('Invalid MThd length');
  }
  final header = reader.readChunk(headerLength);
  final format = header.readInt(2);
  final trackCount = header.readInt(2);
  final ppq = header.readInt(2);
  if (format > 1 ||
      trackCount == 0 ||
      (format == 0 && trackCount != 1) ||
      ppq == 0 ||
      (ppq & 0x8000) != 0) {
    throw const FormatException('Unsupported MIDI header');
  }

  final hits = <MidiHit>[];
  final stepsPerBar = 4 * stepsPerBeat;
  final maxSteps = maxBars * stepsPerBar;
  var tracksRead = 0;
  var lastStep = 0;
  while (!reader.isAtEnd) {
    final chunkType = reader.readInt(4);
    final chunkLength = reader.readInt(4);
    final track = reader.readChunk(chunkLength);
    if (chunkType != 0x4D54726B) continue;
    tracksRead++;
    var tick = 0;
    var runningStatus = 0;
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
        track.readDataByte();
        track.skip(track.readVariableLength());
      } else if (status == 0xF0 || status == 0xF7) {
        runningStatus = 0;
        track.skip(track.readVariableLength());
      } else if (status >= 0x80 && status <= 0xEF) {
        runningStatus = status;
        final data1 = firstData ?? track.readDataByte();
        final type = status & 0xF0;
        final data2 = type == 0xC0 || type == 0xD0 ? 0 : track.readDataByte();
        if (status == 0x99 && data2 > 0) {
          final step = (tick / ppq * stepsPerBeat).round();
          if (step < maxSteps) {
            hits.add(MidiHit(step: step, note: data1, vel: data2));
            if (step > lastStep) lastStep = step;
          }
        }
      } else {
        throw const FormatException('Invalid MIDI event status');
      }
    }
  }
  if (tracksRead != trackCount) {
    throw const FormatException('MIDI track count mismatch');
  }

  hits.sort((a, b) => a.step.compareTo(b.step));
  return MidiPattern(
    name: 'Imported',
    bars: ((lastStep + 1) / stepsPerBar).ceil().clamp(1, maxBars),
    beatsPerBar: 4,
    stepsPerBeat: stepsPerBeat,
    hits: hits,
  );
}

class _SmfReader {
  _SmfReader(this.bytes);

  final Uint8List bytes;
  int _offset = 0;

  bool get isAtEnd => _offset == bytes.length;

  void _require(int length) {
    if (length > bytes.length - _offset) {
      throw const FormatException('Truncated MIDI data');
    }
  }

  int readInt(int length) {
    _require(length);
    var value = 0;
    for (var i = 0; i < length; i++) {
      value = (value << 8) | bytes[_offset++];
    }
    return value;
  }

  int readDataByte() {
    final value = readInt(1);
    if (value >= 0x80) {
      throw const FormatException('Invalid MIDI data byte');
    }
    return value;
  }

  int readVariableLength() {
    var value = 0;
    for (var i = 0; i < 4; i++) {
      final byte = readInt(1);
      value = (value << 7) | (byte & 0x7F);
      if ((byte & 0x80) == 0) return value;
    }
    throw const FormatException('Invalid MIDI variable-length value');
  }

  void skip(int length) {
    _require(length);
    _offset += length;
  }

  _SmfReader readChunk(int length) {
    _require(length);
    final chunk = _SmfReader(
      Uint8List.sublistView(bytes, _offset, _offset + length),
    );
    _offset += length;
    return chunk;
  }
}
