import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/song_lab.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/data/metronome_provider.dart';
import '../../providers/data/midi_song_practice_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../theme/mono_pulse_theme.dart';

// Load once per sheet entry, after the widget tree finishes building.
final _loadMidiSongProvider = FutureProvider.autoDispose
    .family<void, (SongLabEntry, String?)>((ref, key) async {
      final (entry, bandId) = key;
      final practice = ref.watch(midiSongPracticeProvider(entry).notifier);
      await Future<void>.value();
      if (!ref.mounted) return;
      await practice.loadEntry(
        onPersist: (updated) async {
          if (!ref.mounted) return;
          final canEdit = bandId == null
              ? ref.read(canEditProvider)
              : ref.read(canEditBandProvider(bandId));
          if (canEdit) {
            await ref
                .read(labRepositoryProvider)
                .saveEntry(updated, bandId: bandId);
          }
        },
      );
    });

class MidiSongPanel extends ConsumerWidget {
  MidiSongPanel({required this.entry, this.bandId, super.key})
    : assert(entry.midiSong != null, 'A MIDI song is required');

  final SongLabEntry entry;
  final String? bandId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kIsWeb) return const SizedBox.shrink();

    final effectiveBandId = bandId ?? entry.bandId;
    ref.watch(_loadMidiSongProvider((entry, effectiveBandId)));
    final state = ref.watch(midiSongPracticeProvider(entry));
    final practice = ref.read(midiSongPracticeProvider(entry).notifier);
    final metronome = ref.watch(metronomeProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => SafeArea(
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.all(MonoPulseSpacing.lg),
          children: [
            Text(
              entry.title?.isNotEmpty == true ? entry.title! : 'MIDI song',
              style: MonoPulseTypography.titleLarge,
            ),
            Text(
              '${metronome.bpm} BPM',
              style: MonoPulseTypography.bodySmall.copyWith(
                color: context.mp.textSecondary,
              ),
            ),
            const SizedBox(height: MonoPulseSpacing.md),
            if (state.loading) const Center(child: CircularProgressIndicator()),
            if (state.error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  state.error!,
                  style: MonoPulseTypography.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            for (var i = 0; i < state.tracks.length; i++)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(MonoPulseSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.tracks[i].name.isEmpty
                            ? 'Track ${i + 1}'
                            : state.tracks[i].name,
                        style: MonoPulseTypography.titleMedium,
                      ),
                      Text(
                        state.tracks[i].effectiveRole.name,
                        style: MonoPulseTypography.bodySmall.copyWith(
                          color: context.mp.textSecondary,
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Mute'),
                        value: state.tracks[i].mute,
                        onChanged: (mute) => practice.setMute(i, mute: mute),
                      ),
                      Row(
                        children: [
                          const Text('Volume'),
                          Expanded(
                            child: Slider(
                              value: state.tracks[i].volume,
                              label:
                                  '${(state.tracks[i].volume * 100).round()}%',
                              onChanged: (volume) =>
                                  practice.setVolume(i, volume),
                            ),
                          ),
                          FilterChip(
                            label: const Text('Solo'),
                            selected: state.soloed.contains(i),
                            onSelected: (_) => practice.toggleSolo(i),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: MonoPulseSpacing.md),
            FilledButton.icon(
              onPressed:
                  metronome.isPlaying ||
                      (!state.loading && state.tracks.isNotEmpty)
                  ? () => ref.read(metronomeProvider.notifier).toggle()
                  : null,
              icon: Icon(metronome.isPlaying ? Icons.stop : Icons.play_arrow),
              label: Text(metronome.isPlaying ? 'Stop' : 'Play'),
            ),
          ],
        ),
      ),
    );
  }
}
