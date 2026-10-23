import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/song_lab.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/data/midi_hidden_provider.dart';
import '../midi/arrangement_sheet.dart';
import '../midi/midi_import_flow.dart';
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
            onTap: () =>
                open((_) => DrumPracticePanel(songId: songId, bandId: bandId)),
          ),
          for (final e in midiSongs)
            ListTile(
              leading: const Icon(Icons.piano_outlined),
              title: Text(e.title?.isNotEmpty == true ? e.title! : 'MIDI song'),
              subtitle: Text(
                '${e.midiSong!.tracks.length} instruments'
                '${ref.watch(midiHiddenProvider).contains(e.id) ? ' · hidden, tap to show' : ''}',
              ),
              trailing: IconButton(
                tooltip: 'Edit arrangement',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () =>
                    open((_) => ArrangementSheet(entry: e, bandId: bandId)),
              ),
              // A hidden song comes back first; otherwise the old panels open.
              onTap: ref.watch(midiHiddenProvider).contains(e.id)
                  ? () {
                      ref.read(midiHiddenProvider.notifier).show(e.id);
                      Navigator.of(context).pop();
                    }
                  : () => open(
                      (_) => e.midiSong!.sectionMap.isEmpty
                          ? ArrangementSheet(entry: e, bandId: bandId)
                          : MidiSongPanel(entry: e, bandId: bandId),
                    ),
            ),
          if (canImportMidi(ref, bandId))
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Add MIDI file'),
              subtitle: const Text('.mid, .midi or .rmi from this device'),
              onTap: () {
                Navigator.of(context).pop();
                unawaited(
                  pickAndImportMidi(
                    context,
                    ref,
                    songId: songId,
                    bandId: bandId,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
