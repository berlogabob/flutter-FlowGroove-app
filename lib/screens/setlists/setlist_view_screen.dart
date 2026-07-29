import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/lineup.dart';
import '../../models/setlist.dart';
import '../../models/song.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/data/metronome_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../services/export/pdf_service.dart';
import '../../services/export/setlist_export_sheet.dart';
import '../../services/export/setlist_share.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/snackbar.dart';
import '../../widgets/app_menu_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/menu_items_scope.dart';
import '../../widgets/setlist_break_row.dart';
import '../../widgets/setlist_song_row.dart';
import 'create_setlist_screen.dart' show SetlistStorageScope;
import 'event_kit_editor_screen.dart';

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

    // Event Kit reads the LIVE setlist (the constructor arg is a
    // navigation-time snapshot; the editor autosaves, and this keeps the
    // summary current after popping back).
    final liveSetlist =
        (bandId == null
                ? ref.watch(setlistsProvider).value
                : ref.watch(bandSetlistsProvider(bandId!)).value)
            ?.where((s) => s.id == setlist.id)
            .firstOrNull ??
        setlist;

    // Publishes into the shell's bottom bar (this is a pushed branch child):
    // the title slot shows the setlist name (bar becomes [← Back] [name] [⋮]);
    // Open in Metronome / Share / Export to PDF — read actions for everyone —
    // and the editor-only Edit / Event kit live in the Menu sheet.
    return MenuScopePublisher(
      data: MenuScopeData(
        title: setlist.name,
        items: [
          AppMenuItem(
            icon: Icons.av_timer,
            label: 'Open in Metronome',
            onTap: () => _openInMetronome(context, ref, liveSetlist),
          ),
          AppMenuItem(
            icon: Icons.share_outlined,
            label: 'Share',
            onTap: () => _share(context, ref, liveSetlist),
          ),
          AppMenuItem(
            icon: Icons.picture_as_pdf_outlined,
            label: 'Export to PDF',
            onTap: () => _exportPdf(context, ref, liveSetlist),
          ),
          if (canEdit)
            AppMenuItem(
              icon: Icons.edit_outlined,
              label: 'Edit Setlist',
              // Carry the scope through: the editor decides which collection to
              // save to from these, and without them a band setlist is written
              // to the personal one — where the list then hides it, because it
              // filters out entries with a bandId. The save looks like it
              // worked and the edit is simply gone.
              onTap: () => context.pushNamed(
                'edit-setlist',
                pathParameters: {'id': setlist.id},
                queryParameters: {
                  'bandId': ?bandId,
                  'scope': storageScope.name,
                },
                extra: setlist,
              ),
            ),
          if (canEdit)
            AppMenuItem(
              icon: Icons.theater_comedy_outlined,
              label: 'Event kit',
              onTap: () => _openEventKit(context, liveSetlist),
            ),
        ],
      ),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: songsAsync.when(
            data: (songs) =>
                _buildBody(context, liveSetlist, songs, canEdit: canEdit),
            loading: () => const LoadingIndicator(),
            // A failed songs load shouldn't block the setlist details from
            // showing; song rows just fall back to "unavailable".
            error: (_, _) =>
                _buildBody(context, liveSetlist, const [], canEdit: canEdit),
          ),
        ),
      ),
    );
  }

  void _openEventKit(BuildContext context, Setlist live) {
    // rootNavigator: cover the shell so its bottom bar doesn't stack under the
    // editor's own bar (the double-bar bug).
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => EventKitEditorScreen(setlist: live, bandId: bandId),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    Setlist setlist,
    List<Song> allSongs, {
    required bool canEdit,
  }) {
    final songsById = {for (final song in allSongs) song.id: song};
    final items = setlist.effectiveItems;
    final lineup = peopleById(setlist.eventKit?.people ?? const []);

    if (items.isEmpty && (setlist.eventKit?.isEmpty ?? true)) {
      return const EmptyState(
        icon: Icons.music_note,
        message: 'No songs in this setlist',
      );
    }

    // Number songs per section — the counter resets after each break, matching
    // a real printed setlist where each section restarts at 1.
    var songNumber = 0;
    final numbers = <int>[];
    for (final item in items) {
      if (item.isBreak) {
        numbers.add(-1);
        songNumber = 0;
      } else {
        numbers.add(songNumber++);
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.all(MonoPulseSpacing.lg),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item.isBreak) {
          return SetlistBreakRow(
            breakType: item.breakType,
            label: item.breakLabel,
          );
        }
        final song = songsById[item.songId];
        return SetlistSongRow(
          index: numbers[index],
          song: song,
          performers: performerLabel(item.performerIds, lineup),
          trailing: song == null ? null : _badgesFor(song),
          onTap: song == null ? null : () => _openSong(context, song),
        );
      },
    );
  }


  /// Key/BPM badges shown when the row's song resolves. Mirrors the
  /// editable rows in `CreateSetlistScreen`.
  Widget _badgesFor(Song song) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MonoPulseSpacing.md,
            vertical: MonoPulseSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: MonoPulseColors.accentOrange10,
            borderRadius: BorderRadius.circular(MonoPulseRadius.small),
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
    );
  }

  /// Opens the tapped song's editor, band-scoped when this is a band setlist
  /// (bandId makes the save target the band's copy — see BandSongsScreen).
  void _openSong(BuildContext context, Song song) {
    context.pushNamed(
      'edit-song',
      pathParameters: {'id': song.id},
      extra: bandId == null ? song : {'song': song, 'bandId': bandId},
    );
  }

  /// The setlist's songs in `songIds` order. The band-songs provider is
  /// autoDispose, so awaiting `.future` (rather than a cold `.value` read)
  /// avoids the "disposed during loading" empty result (#80).
  Future<List<Song>> _resolveSongs(WidgetRef ref, Setlist setlist) async {
    final allSongs = await ref.read(
      bandId == null ? songsProvider.future : bandSongsProvider(bandId!).future,
    );
    final songsById = {for (final song in allSongs) song.id: song};
    return setlist.songIds
        .map((id) => songsById[id])
        .whereType<Song>()
        .toList();
  }

  /// Mirrors `SetlistsListScreen._openInMetronome`: loads the current songs,
  /// hands them to the metronome queue, and pushes the metronome screen.
  Future<void> _openInMetronome(
    BuildContext context,
    WidgetRef ref,
    Setlist setlist,
  ) async {
    final songs = await _resolveSongs(ref, setlist);
    if (!context.mounted) return;
    final loaded = ref
        .read(metronomeProvider.notifier)
        .loadSetlistQueue(
          setlist,
          availableSongs: songs,
          sourceBandId: bandId,
        );
    if (!loaded) {
      showAppSnackBar(
        context,
        'This setlist is empty or has unavailable songs.',
      );
      return;
    }
    await context.pushNamed('metronome');
  }

  Future<void> _share(
    BuildContext context,
    WidgetRef ref,
    Setlist setlist,
  ) async {
    final songs = await _resolveSongs(ref, setlist);
    if (!context.mounted) return;
    shareSetlistLinks(context, setlist, songs);
  }

  Future<void> _exportPdf(
    BuildContext context,
    WidgetRef ref,
    Setlist setlist,
  ) async {
    final choice = await pickSetlistPdfExport(context, setlist);
    if (choice == null) return;
    try {
      await PdfService.exportSetlist(
        setlist,
        await _resolveSongs(ref, setlist),
        layout: choice.layout,
        performerId: choice.performerId,
      );
    } catch (e) {
      if (!context.mounted) return;
      showAppSnackBar(context, 'Error: $e');
    }
  }
}
