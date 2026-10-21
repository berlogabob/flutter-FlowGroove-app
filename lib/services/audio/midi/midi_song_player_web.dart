import 'dart:typed_data';

import 'midi_song_player.dart';

MidiSongPlayer createMidiSongPlayer() => _WebMidiSongPlayer();

// Web song playback is not supported yet.
class _WebMidiSongPlayer implements MidiSongPlayer {
  @override
  Future<void> load(
    List<Int16List> trackBuffers, {
    int sampleRate = 44100,
  }) async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  void setTrackGain(int index, double gain) {}

  @override
  Duration get position => Duration.zero;

  @override
  Future<void> dispose() async {}
}
