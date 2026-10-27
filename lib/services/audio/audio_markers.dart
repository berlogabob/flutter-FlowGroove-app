import 'dart:convert';
import 'dart:typed_data';

/// A single marker embedded in a song file.
class AudioMarker {
  const AudioMarker({required this.ms, this.name = '', this.endMs});

  /// Start of the marker in milliseconds.
  final int ms;

  /// Human readable label.
  final String name;

  /// End of the marker in milliseconds, when the file marks a region.
  final int? endMs;
}

/// Markers embedded in a song file: WAV cue points (+ LIST/adtl labl names,
/// ltxt lengths -> endMs) and MP3 ID3v2 CHAP frames (+ TIT2 sub-frame names).
/// Returns [] for anything else or on malformed data (never throws).
List<AudioMarker> readAudioMarkers(Uint8List bytes) {
  try {
    if (bytes.length >= 12 &&
        _asciiEquals(bytes, 0, 'RIFF') &&
        _asciiEquals(bytes, 8, 'WAVE')) {
      final result = _readWav(bytes);
      if (result != null) {
        result.sort((a, b) => a.ms.compareTo(b.ms));
        return result;
      }
    }

    if (bytes.length >= 10 && _asciiEquals(bytes, 0, 'ID3')) {
      final result = _readMp3Id3v2(bytes);
      if (result != null) {
        result.sort((a, b) => a.ms.compareTo(b.ms));
        return result;
      }
    }
  } on Object {
    // Malformed data must never throw.
  }
  return <AudioMarker>[];
}

// ---------------------------------------------------------------------------
// WAV (RIFF little-endian)
// ---------------------------------------------------------------------------

List<AudioMarker>? _readWav(Uint8List b) {
  // Chunks start after "RIFF" + size(4) + "WAVE" = 12 bytes.
  int offset = 12;
  int sampleRate = 44100;
  final List<int> cueIds = <int>[];
  final List<int> cueMss = <int>[];
  final Map<int, int> cueIdToMs = <int, int>{};
  final Map<int, String> cueNames = <int, String>{};
  final Map<int, int> cueEndMss = <int, int>{};

  while (offset + 8 <= b.length) {
    final String id = _readAscii(b, offset, 4);
    final int size = _readU32LE(b, offset + 4);
    final int dataStart = offset + 8;
    final int dataEnd = dataStart + size;
    if (dataEnd > b.length) break;

    switch (id) {
      case 'fmt ':
        if (dataStart + 8 <= dataEnd) {
          sampleRate = _readU32LE(b, dataStart + 4);
        }
        break;
      case 'cue ':
        if (dataStart + 4 <= dataEnd) {
          final int count = _readU32LE(b, dataStart);
          for (int i = 0; i < count; i++) {
            final int base = dataStart + 4 + i * 24;
            if (base + 24 > dataEnd) break;
            // id(u32), position(u32), fccChunk(4), chunkStart(u32),
            // blockStart(u32), sampleOffset(u32)
            final int cuePointId = _readU32LE(b, base);
            final int sampleOffset = _readU32LE(b, base + 20);
            if (sampleRate <= 0) break;
            final int ms = sampleOffset * 1000 ~/ sampleRate;
            cueIdToMs[cuePointId] = ms;
            cueIds.add(cuePointId);
            cueMss.add(ms);
          }
        }
        break;
      case 'LIST':
        if (dataStart + 4 <= dataEnd && _asciiEquals(b, dataStart, 'adtl')) {
          _readAdtlSubchunks(
            b,
            dataStart,
            dataEnd,
            sampleRate,
            cueIdToMs,
            cueNames,
            cueEndMss,
          );
        }
        break;
    }

    // Chunks are word-aligned: pad byte when size is odd.
    offset = dataEnd + (size.isOdd ? 1 : 0);
  }

  if (cueMss.isEmpty) return null;

  final List<AudioMarker> markers = <AudioMarker>[];
  for (int i = 0; i < cueMss.length; i++) {
    final int cueId = cueIds[i];
    markers.add(
      AudioMarker(
        ms: cueMss[i],
        name: cueNames[cueId] ?? '',
        endMs: cueEndMss[cueId],
      ),
    );
  }
  return markers;
}

void _readAdtlSubchunks(
  Uint8List b,
  int listStart,
  int listEnd,
  int sampleRate,
  Map<int, int> cueIdToMs,
  Map<int, String> cueNames,
  Map<int, int> cueEndMss,
) {
  int offset = listStart + 4; // skip "adtl"
  while (offset + 8 <= listEnd) {
    final String subId = _readAscii(b, offset, 4);
    final int size = _readU32LE(b, offset + 4);
    final int dataStart = offset + 8;
    final int dataEnd = dataStart + size;
    if (dataEnd > listEnd) break;

    if (subId == 'labl' && dataStart < dataEnd) {
      final int cuePointId = _readU32LE(b, dataStart);
      final int textStart = dataStart + 4;
      int end = textStart;
      while (end < dataEnd && b[end] != 0) end++;
      final String name = utf8.decode(
        b.sublist(textStart, end),
        allowMalformed: true,
      );
      cueNames[cuePointId] = name;
    } else if (subId == 'ltxt' && dataStart + 8 <= dataEnd) {
      final int cuePointId = _readU32LE(b, dataStart);
      final int sampleLength = _readU32LE(b, dataStart + 4);
      final start = cueIdToMs[cuePointId];
      if (start != null && sampleRate > 0) {
        cueEndMss[cuePointId] = start + sampleLength * 1000 ~/ sampleRate;
      }
    }

    offset = dataEnd + (size.isOdd ? 1 : 0);
  }
}

// ---------------------------------------------------------------------------
// MP3 ID3v2
// ---------------------------------------------------------------------------

List<AudioMarker>? _readMp3Id3v2(Uint8List b) {
  // "ID3" ver[3] flags[4] size[5..8]
  final int ver = b[3];
  if (ver != 3 && ver != 4) return null;

  final int tagSize = _readSyncsafe(b, 6);
  final int tagEnd = 10 + tagSize;
  if (tagEnd > b.length) return null;

  final List<AudioMarker> markers = <AudioMarker>[];
  int offset = 10;
  while (offset + 10 <= tagEnd) {
    final String fid = _readAscii(b, offset, 4);
    if (fid.isEmpty || fid[0] == '\u0000') break;
    final int frameSize = ver == 4
        ? _readSyncsafe(b, offset + 4)
        : _readU32BE(b, offset + 4);
    final int dataStart = offset + 10;
    final int dataEnd = dataStart + frameSize;
    if (dataEnd > tagEnd) break;

    if (fid == 'CHAP' && dataStart < dataEnd) {
      final marker = _readChap(b, dataStart, dataEnd, ver);
      if (marker != null) markers.add(marker);
    }

    offset = dataEnd;
  }

  if (markers.isEmpty) return null;
  return markers;
}

AudioMarker? _readChap(Uint8List b, int dataStart, int dataEnd, int ver) {
  // element id (zero-terminated latin1)
  int p = dataStart;
  if (p >= dataEnd || b[p] == 0) return null;
  int idEnd = p;
  while (idEnd < dataEnd && b[idEnd] != 0) idEnd++;
  final String elementId = String.fromCharCodes(b.sublist(p, idEnd));
  if (elementId.isEmpty) return null;

  p = idEnd + 1;
  // startTime u32 BE, endTime u32 BE, startOffset u32, endOffset u32
  if (p + 16 > dataEnd) return null;
  final int startTime = _readU32BE(b, p);
  final int endTime = _readU32BE(b, p + 4);
  int subStart = p + 16;

  String name = '';
  while (subStart + 10 <= dataEnd) {
    final String subId = _readAscii(b, subStart, 4);
    if (subId.isEmpty || subId[0] == '\u0000') break;
    final int subSize = ver == 4
        ? _readSyncsafe(b, subStart + 4)
        : _readU32BE(b, subStart + 4);
    final int subDataStart = subStart + 10;
    final int subDataEnd = subDataStart + subSize;
    if (subDataEnd > dataEnd) break;

    if (subId == 'TIT2' && subSize > 0) {
      name = _decodeTit2(b, subDataStart, subSize);
    }

    subStart = subDataEnd;
  }

  return AudioMarker(ms: startTime, name: name, endMs: endTime);
}

String _decodeTit2(Uint8List b, int start, int bodyLen) {
  if (bodyLen <= 0) return '';
  final int enc = b[start];
  // Growable copy: trailing NULs and the BOM are removed in place.
  final List<int> rest = b.sublist(start + 1, start + bodyLen).toList();
  while (rest.isNotEmpty && rest.last == 0) rest.removeLast();

  if (enc == 0 || enc == 3) {
    return enc == 3
        ? utf8.decode(rest, allowMalformed: true)
        : String.fromCharCodes(rest);
  }
  if (enc == 1 || enc == 2) {
    if (rest.length >= 2 && rest[0] == 0xFF && rest[1] == 0xFE) {
      rest.removeRange(0, 2);
    } else if (rest.length >= 2 && rest[0] == 0xFE && rest[1] == 0xFF) {
      rest.removeRange(0, 2);
    }
    final List<int> units = <int>[];
    for (int i = 0; i + 1 < rest.length; i += 2) {
      units.add(rest[i] | (rest[i + 1] << 8));
    }
    return String.fromCharCodes(units);
  }
  return String.fromCharCodes(rest);
}

// ---------------------------------------------------------------------------
// Low-level readers
// ---------------------------------------------------------------------------

bool _asciiEquals(Uint8List b, int offset, String s) {
  if (offset + s.length > b.length) return false;
  for (int i = 0; i < s.length; i++) {
    if (b[offset + i] != s.codeUnitAt(i)) return false;
  }
  return true;
}

String _readAscii(Uint8List b, int offset, int len) {
  final int end = (offset + len > b.length) ? b.length : offset + len;
  return String.fromCharCodes(b.sublist(offset, end));
}

int _readU32LE(Uint8List b, int offset) {
  return b[offset] |
      (b[offset + 1] << 8) |
      (b[offset + 2] << 16) |
      (b[offset + 3] << 24);
}

int _readU32BE(Uint8List b, int offset) {
  return (b[offset] << 24) |
      (b[offset + 1] << 16) |
      (b[offset + 2] << 8) |
      b[offset + 3];
}

int _readSyncsafe(Uint8List b, int offset) {
  return ((b[offset] & 0x7f) << 21) |
      ((b[offset + 1] & 0x7f) << 14) |
      ((b[offset + 2] & 0x7f) << 7) |
      (b[offset + 3] & 0x7f);
}
