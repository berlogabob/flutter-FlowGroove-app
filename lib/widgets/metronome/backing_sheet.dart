import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/song_lab.dart';
import '../../providers/data/data_providers.dart';
import '../midi/midi_song_panel.dart';
import 'drum_practice_panel.dart';

/// Entry point from the metronome: drum patterns plus every imported MIDI song
/// (all instruments) attached to the active song.
class BackingSheet extends ConsumerWidget {
  const BackingSheet({required this.songId, this.bandId, super.key});

  final String songId;
  final String? bandId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries =
        ref.watch(labEntriesProvider((songId, bandId))).value ??
        const <SongLabEntry>[];
    final midiSongs = entries
        .where((e) => e.type == LabEntryType.midi && e.midiSong != null)
        .toList();

    void open(Widget Function(BuildContext) builder) {
      Navigator.of(context).pop();
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: builder,
      );
    }

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.album_outlined),
            title: const Text('Drum pattern'),
            subtitle: const Text('Grid, import, sync with click'),
            onTap: () => open(
              (_) => DrumPracticePanel(songId: songId, bandId: bandId),
            ),
          ),
          for (final e in midiSongs)
            ListTile(
              leading: const Icon(Icons.piano_outlined),
              title: Text(
                e.title?.isNotEmpty == true ? e.title! : 'MIDI song',
              ),
              subtitle: Text('${e.midiSong!.tracks.length} instruments'),
              onTap: () =>
                  open((_) => MidiSongPanel(entry: e, bandId: bandId)),
            ),
          if (midiSongs.isEmpty)
            const ListTile(
              title: Text('No MIDI songs yet'),
              subtitle: Text('Import one from the song\'s Song Lab.'),
            ),
        ],
      ),
    );
  }
}
