import 'package:flutter_riverpod/flutter_riverpod.dart';

/// MIDI entries the user hid from the metronome this session (the launchpad
/// gives way to the plain metronome). Entries stay on the song.
class MidiHiddenNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void hide(String entryId) => state = {...state, entryId};
  void show(String entryId) => state = {...state}..remove(entryId);
}

final midiHiddenProvider = NotifierProvider<MidiHiddenNotifier, Set<String>>(
  MidiHiddenNotifier.new,
);
