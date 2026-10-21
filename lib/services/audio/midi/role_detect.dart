import '../../../models/midi_song.dart';

/// Detects a track's role using zero-based MIDI channels and programs.
MidiRole detectRole({
  required String name,
  required int channel,
  required int program,
  required int maxPitch,
}) {
  if (channel == 9) return MidiRole.drums;

  final lowerName = name.toLowerCase();
  const hints = [
    (MidiRole.drums, ['drum', 'perc']),
    (MidiRole.bass, ['bass']),
    (MidiRole.guitar, ['guitar', 'gtr']),
    (MidiRole.vocal, ['vocal', 'vox', 'voice', 'choir', 'sing']),
    (MidiRole.keys, ['piano', 'keys', 'organ']),
    (MidiRole.strings, ['string', 'violin', 'cello']),
    (MidiRole.lead, ['lead', 'melody', 'solo']),
  ];
  for (final (role, keywords) in hints) {
    if (keywords.any(lowerName.contains)) return role;
  }

  if (program == 0 && maxPitch <= 55) return MidiRole.bass;
  return switch (program) {
    >= 0 && <= 23 => MidiRole.keys,
    >= 24 && <= 31 => MidiRole.guitar,
    >= 32 && <= 39 => MidiRole.bass,
    >= 52 && <= 54 => MidiRole.vocal,
    >= 40 && <= 55 => MidiRole.strings,
    >= 56 && <= 79 => MidiRole.lead,
    >= 80 && <= 103 => MidiRole.synth,
    _ => MidiRole.other,
  };
}
