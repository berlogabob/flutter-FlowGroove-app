import '../../../models/midi_song.dart';

({double bpm, int bars, int leadInBars, bool hasTempoEvent}) factsOf(
  MidiSongData d, {
  int beatsPerBar = 4,
}) {
  if (d.ppq < 1 || beatsPerBar < 1) {
    throw ArgumentError('ppq and beatsPerBar must be positive');
  }

  final tempo = d.tempos.where((tempo) => tempo.tick == 0).firstOrNull;
  final ticksPerBar = d.ppq * beatsPerBar;
  int? firstTick;
  var lastEndTick = 0;
  for (final track in d.tracks) {
    for (final note in track.notes) {
      if (firstTick == null || note.tick < firstTick) firstTick = note.tick;
      final endTick = note.tick + note.dur;
      if (endTick > lastEndTick) lastEndTick = endTick;
    }
  }

  return (
    bpm: tempo == null ? 120.0 : 60000000 / tempo.microsPerQuarter,
    bars: (lastEndTick / ticksPerBar).ceil(),
    leadInBars: ((firstTick ?? 0) / ticksPerBar).floor(),
    hasTempoEvent: tempo != null,
  );
}
