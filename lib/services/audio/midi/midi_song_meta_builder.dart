import '../../../models/midi_song.dart';
import 'gm_names.dart';
import 'role_detect.dart';

MidiSongMeta buildMidiSongMeta(
  MidiSongData song, {
  String? fileUrl,
  MidiSongMeta? previous,
}) {
  final previousTracks = {
    for (final track in previous?.tracks ?? <MidiTrackMeta>[])
      (track.index, track.channel): track,
  };
  final nameCounts = <String, int>{};
  for (final track in song.tracks) {
    if (track.hasTrackName) {
      nameCounts.update(track.name, (count) => count + 1, ifAbsent: () => 1);
    }
  }

  return MidiSongMeta(
    fileUrl: fileUrl,
    ppq: song.ppq,
    initialBpm: song.initialBpm,
    tracks: song.tracks.map((track) {
      final saved = previousTracks[(track.index, track.channel)];
      final minPitch = track.minPitch;
      final maxPitch = track.maxPitch;
      final name =
          !track.hasTrackName ||
              track.name.isEmpty ||
              (nameCounts[track.name] ?? 0) > 1
          ? '${track.channel == 9 ? 'Drums' : gmProgramName(track.program)} · ch ${track.channel + 1}'
          : track.name;
      return MidiTrackMeta(
        index: track.index,
        name: String.fromCharCodes(name.runes.take(80)),
        channel: track.channel,
        program: track.program,
        detectedRole: detectRole(
          channel: track.channel,
          program: track.program,
          name: track.name,
          maxPitch: maxPitch,
        ),
        noteCount: track.noteCount,
        minPitch: minPitch,
        maxPitch: maxPitch,
        roleOverride: saved?.roleOverride,
        programOverride: saved?.programOverride,
        mute: saved?.mute ?? false,
        volume: saved?.volume ?? 1.0,
      );
    }).toList(),
  );
}
