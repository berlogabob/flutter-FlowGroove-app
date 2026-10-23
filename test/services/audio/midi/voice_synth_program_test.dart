import 'dart:typed_data';

import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/services/audio/midi/voice_synth.dart';
import 'package:flutter_test/flutter_test.dart';

Float32List render({int? program, MidiRole role = MidiRole.keys}) {
  final output = Float32List(4240);
  addVoice(
    output,
    sampleRate: 8000,
    startSample: 0,
    durationSamples: 4000,
    pitch: 60,
    velocity01: 0.8,
    role: role,
    program: program,
  );
  return output;
}

Uint8List bytes(Float32List output) => output.buffer.asUint8List();

bool hasProgramVoice(int program) =>
    (program >= 8 && program <= 23) ||
    (program >= 56 && program <= 63) ||
    (program >= 88 && program <= 95);

void main() {
  test(
    'organ program changes the keys buffer at the same pitch and velocity',
    () {
      expect(bytes(render(program: 19)), isNot(orderedEquals(bytes(render()))));
    },
  );

  test('null and program 0 render bit-identical keys buffers', () {
    expect(bytes(render()), orderedEquals(bytes(render(program: 0))));
  });

  test(
    'programs outside the timbre ranges preserve every role bit for bit',
    () {
      for (final role in MidiRole.values) {
        final reference = bytes(render(role: role));
        for (var program = -1; program <= 128; program++) {
          if (hasProgramVoice(program)) continue;
          expect(
            bytes(render(program: program, role: role)),
            orderedEquals(reference),
            reason: '${role.name}, program $program',
          );
        }
      }
    },
  );

  test(
    'program timbres override melodic roles and leave drums bit-identical',
    () {
      final drums = bytes(render(role: MidiRole.drums));
      for (final program in [8, 15, 16, 23, 56, 63, 88, 95]) {
        final reference = bytes(render(program: program));
        expect(reference, isNot(orderedEquals(bytes(render()))));
        for (final role in MidiRole.values) {
          expect(
            bytes(render(program: program, role: role)),
            orderedEquals(role == MidiRole.drums ? drums : reference),
            reason: '${role.name}, program $program',
          );
        }
      }
    },
  );

  test('all programs and roles render finite, non-silent output', () {
    for (final role in MidiRole.values) {
      for (final program in <int?>[null, ...List.generate(128, (i) => i)]) {
        final output = render(program: program, role: role);
        final reason = '${role.name}, program $program';
        expect(
          output.every((sample) => sample.isFinite),
          isTrue,
          reason: reason,
        );
        expect(output.any((sample) => sample != 0), isTrue, reason: reason);
      }
    }
  });
}
