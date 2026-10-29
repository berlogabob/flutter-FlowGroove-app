import 'dart:typed_data';

export 'midi_song_player_soloud.dart'
    if (dart.library.js_interop) 'midi_song_player_web.dart'
    show createMidiSongPlayer;

abstract class MidiSongPlayer {
  Future<void> load(List<Int16List> trackBuffers, {int sampleRate = 44100});
  Future<void> start();
  Future<void> stop();
  void setTrackGain(int index, double gain);
  Duration get position;
  Future<void> dispose();
}
