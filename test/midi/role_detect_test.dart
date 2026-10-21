import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/services/audio/midi/role_detect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('detectRole', () {
    final cases = [
      for (var program = 0; program < 128; program++)
        ('Bass', 9, program, 48, MidiRole.drums),
      ('', 0, 33, 72, MidiRole.bass),
      ('', 0, 25, 72, MidiRole.guitar),
      ('', 0, 0, 72, MidiRole.keys),
      ('', 0, 40, 72, MidiRole.strings),
      ('', 0, 53, 72, MidiRole.vocal),
      ('', 0, 73, 72, MidiRole.lead),
      ('', 0, 81, 72, MidiRole.synth),
      ('Lead Vox', 0, 25, 72, MidiRole.vocal),
      ('Bass', 0, 0, 72, MidiRole.bass),
      ('', 0, 0, 48, MidiRole.bass),
      ('Unknown', 0, 112, 72, MidiRole.other),
      ('', 0, 112, 72, MidiRole.other),
    ];

    for (final (name, channel, program, maxPitch, expected) in cases) {
      test('name="$name", channel=$channel, program=$program, '
          'maxPitch=$maxPitch -> ${expected.name}', () {
        expect(
          detectRole(
            name: name,
            channel: channel,
            program: program,
            maxPitch: maxPitch,
          ),
          expected,
        );
      });
    }
  });
}
