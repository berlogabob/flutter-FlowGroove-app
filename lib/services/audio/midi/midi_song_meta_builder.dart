import '../../../models/midi_song.dart';
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

  return MidiSongMeta(
    fileUrl: fileUrl,
    ppq: song.ppq,
    initialBpm: song.initialBpm,
    tracks: song.tracks.map((track) {
      final saved = previousTracks[(track.index, track.channel)];
      final minPitch = track.minPitch;
      final maxPitch = track.maxPitch;
      return MidiTrackMeta(
        index: track.index,
        name: track.name,
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
        mute: saved?.mute ?? false,
        volume: saved?.volume ?? 1.0,
      );
    }).toList(),
  );
}
