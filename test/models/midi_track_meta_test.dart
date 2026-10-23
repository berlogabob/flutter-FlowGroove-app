import 'dart:convert';

import 'package:flowgroove/models/midi_song.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const track = MidiTrackMeta(
    index: 2,
    name: 'Bass',
    channel: 1,
    program: 33,
    detectedRole: MidiRole.bass,
    programOverride: 19,
    noteCount: 123,
    minPitch: 28,
    maxPitch: 64,
  );

  test('JSON round trip preserves program override', () {
    final json = track.toJson();
    final restored = MidiTrackMeta.fromJson(
      jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
    );

    expect(json['programOverride'], 19);
    expect(restored.programOverride, 19);
    expect(restored.toJson(), json);
  });

  test(
    'missing program override defaults to null and is omitted from JSON',
    () {
      final restored = MidiTrackMeta.fromJson({'program': 33});

      expect(restored.programOverride, isNull);
      expect(restored.toJson(), isNot(contains('programOverride')));
    },
  );

  test('effective program uses override when set and program otherwise', () {
    expect(track.effectiveProgram, 19);
    expect(MidiTrackMeta.fromJson({'program': 33}).effectiveProgram, 33);
  });

  test('copyWith preserves omitted program override and can clear it', () {
    expect(track.copyWith(mute: true).programOverride, 19);
    expect(track.copyWith(programOverride: 20).effectiveProgram, 20);

    final cleared = track.copyWith(programOverride: null);

    expect(cleared.programOverride, isNull);
    expect(cleared.effectiveProgram, 33);
    expect(cleared.toJson(), isNot(contains('programOverride')));
    expect(track.programOverride, 19);
  });

  test('fromJson clamps program override to 127', () {
    final restored = MidiTrackMeta.fromJson({'programOverride': 200});

    expect(restored.programOverride, 127);
  });
}
