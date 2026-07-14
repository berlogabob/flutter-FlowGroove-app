import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/setlist.dart';
import '../../models/song.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/data/metronome_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/snackbar.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/primary_action_bar.dart';
import 'create_setlist_screen.dart' show SetlistStorageScope;

/// Read-only detail view for a setlist (P1-7 fix).
///
/// Reached by tapping a setlist card on the Setlists tab. Previously a tap
/// opened `CreateSetlistScreen` directly in edit mode ('Edit Setlist', drag
/// handles, Save Changes) — one accidental tap away from an edit, and a dead
/// end for read-only members. This screen shows the setlist's songs without
/// any edit affordances; 'Edit' (app bar action, hidden for read-only users)
/// is now a deliberate, separate step.
class SetlistViewScreen extends ConsumerWidget {
  const SetlistViewScreen({
    required this.setlist,
    super.key,
    this.bandId,
    this.storageScope = SetlistStorageScope.personal,
  });

  /// The setlist to display. Null while `SetlistRouteResolver` (in
  /// app_router.dart) is still resolving the live setlist and has no
  /// navigation-time snapshot to fall back to.
  final Setlist? setlist;
  final String? bandId;
  final SetlistStorageScope storageScope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setlist = this.setlist;
    if (setlist == null) {
      return const Scaffold(body: Center(child: LoadingIndicator()));
    }

    final canEdit = ref.watch(canEditProvider);
    final songsAsync = bandId == null
        ? ref.watch(songsProvider)
        : ref.watch(bandSongsProvider(bandId!));

    return Scaffold(
      appBar: CustomAppBar.build(
        context,
        title: setlist.name,
        actions: [
          if (canEdit)
            TextButton(
              onPressed: () => context.pushNamed(
                'edit-setlist',
                pathParameters: {'id': setlist.id},
                extra: setlist,
              ),
              child: const Text('Edit'),
            ),
        ],
      ),
      body: songsAsync.when(
        data: (songs) => _buildBody(setlist, songs),
        loading: () => const LoadingIndicator(),
        // A failed songs load shouldn't block the setlist details from
        // showing; song rows just fall back to "unavailable".
        error: (_, _) => _buildBody(setlist, const []),
      ),
      bottomNavigationBar: PrimaryActionBar(
        label: 'Open in Metronome',
        icon: Icons.av_timer,
        onPressed: () => _openInMetronome(context, ref, setlist),
      ),
    );
  }

  Widget _buildBody(Setlist setlist, List<Song> allSongs) {
    final songsById = {for (final song in allSongs) song.id: song};
    final items = setlist.effectiveItems;

    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.music_note,
        message: 'No songs in this setlist',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(MonoPulseSpacing.lg),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final song = songsById[items[index].songId];
        return _SongRow(index: index, song: song);
      },
    );
  }

  /// Mirrors `SetlistsListScreen._openInMetronome`: loads the current songs,
  /// hands them to the metronome queue, and pushes the metronome screen.
  Future<void> _openInMetronome(
    BuildContext context,
    WidgetRef ref,
    Setlist setlist,
  ) async {
    final allSongs = await ref.read(
      bandId == null
          ? songsProvider.future
          : bandSongsProvider(bandId!).future,
    );
    final songs = allSongs.where((s) => setlist.songIds.contains(s.id)).toList();
    if (!context.mounted) return;
    final loaded = ref
        .read(metronomeProvider.notifier)
        .loadSetlistQueue(setlist, availableSongs: songs);
    if (!loaded) {
      showAppSnackBar(
        context,
        'This setlist is empty or has unavailable songs.',
      );
      return;
    }
    await context.pushNamed('metronome');
  }
}

/// A single read-only song row. Visually mirrors the key/BPM badges used in
/// `CreateSetlistScreen`'s editable rows, minus the drag handle and delete
/// swipe — this screen never mutates the setlist.
class _SongRow extends StatelessWidget {
  const _SongRow({required this.index, required this.song});

  final int index;
  final Song? song;

  @override
  Widget build(BuildContext context) {
    final song = this.song;
    return Card(
      margin: const EdgeInsets.only(bottom: MonoPulseSpacing.md),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: MonoPulseColors.surfaceRaised,
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              color: MonoPulseColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(
          song?.title ?? 'Unavailable song',
          style: const TextStyle(color: MonoPulseColors.textPrimary),
        ),
        subtitle: song != null
            ? Text(
                song.artist,
                style: const TextStyle(color: MonoPulseColors.textSecondary),
              )
            : null,
        trailing: song == null
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MonoPulseSpacing.md,
                      vertical: MonoPulseSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: MonoPulseColors.accentOrange10,
                      borderRadius: BorderRadius.circular(
                        MonoPulseRadius.small,
                      ),
                    ),
                    child: Text(
                      song.ourKey ?? '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: MonoPulseColors.accentOrange,
                      ),
                    ),
                  ),
                  if (song.ourBPM != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${song.ourBPM}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
