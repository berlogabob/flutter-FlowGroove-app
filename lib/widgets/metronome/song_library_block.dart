import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/band.dart';
import '../../models/setlist.dart';
import '../../models/song.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/data/metronome_provider.dart';
import '../../theme/mono_pulse_theme.dart';
import '../error_banner.dart';

class SongLibraryBlock extends ConsumerWidget {
  const SongLibraryBlock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(metronomeProvider);
    final notifier = ref.read(metronomeProvider.notifier);
    final activeSong = state.activeSong;

    return Column(
      children: [
        Semantics(
          button: true,
          label: 'Open songs and setlists',
          child: InkWell(
            borderRadius: BorderRadius.circular(MonoPulseRadius.huge),
            onTap: () {
              HapticFeedback.lightImpact();
              _openLibrarySheet(context, ref, notifier);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: MonoPulseSpacing.xl,
                vertical: MonoPulseSpacing.md,
              ),
              decoration: BoxDecoration(
                color: MonoPulseColors.surface,
                borderRadius: BorderRadius.circular(MonoPulseRadius.huge),
                border: Border.all(color: MonoPulseColors.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.library_music_outlined,
                    color: MonoPulseColors.textSecondary,
                    size: MonoPulseIcons.sizeMedium,
                  ),
                  const SizedBox(width: MonoPulseSpacing.md),
                  Text(
                    'Songs & Setlists',
                    style: MonoPulseTypography.bodyLarge.copyWith(
                      color: MonoPulseColors.textHighEmphasis,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (activeSong != null) ...[
          const SizedBox(height: MonoPulseSpacing.sm),
          _LoadedSongCard(
            song: activeSong,
            setlist: state.loadedSetlist,
            sourceBandId: state.sourceBandId,
            position: state.currentSetlistIndex + 1,
            total: state.loadedSetlistSongs.length,
            onClear: notifier.clearLoadedContent,
          ),
        ],
      ],
    );
  }

  void _openLibrarySheet(
    BuildContext context,
    WidgetRef ref,
    MetronomeNotifier notifier,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: MonoPulseColors.transparent,
      builder: (sheetContext) => _SongLibrarySheet(
        onLoadSong: (song, bandId) {
          HapticFeedback.mediumImpact();
          notifier.loadSongTempo(song, sourceBandId: bandId);
          Navigator.of(sheetContext).pop();
        },
        onLoadSetlist: (setlist, songs, bandId) {
          HapticFeedback.mediumImpact();
          final loaded = notifier.loadSetlistQueue(
            setlist,
            availableSongs: songs,
            sourceBandId: bandId,
          );
          if (loaded) {
            Navigator.of(sheetContext).pop();
          } else {
            ScaffoldMessenger.of(sheetContext).showSnackBar(
              const SnackBar(
                content: Text(
                  'This setlist is empty or contains unavailable songs.',
                ),
              ),
            );
          }
        },
      ),
    );
  }
}

class _LoadedSongCard extends ConsumerWidget {
  const _LoadedSongCard({
    required this.song,
    required this.setlist,
    required this.sourceBandId,
    required this.position,
    required this.total,
    required this.onClear,
  });

  final Song song;
  final Setlist? setlist;
  final String? sourceBandId;
  final int position;
  final int total;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bands = ref.watch(bandsProvider).value ?? const <Band>[];
    final bandName = bands
        .where((band) => band.id == sourceBandId)
        .map((band) => band.name)
        .firstOrNull;
    final sourceLabel = bandName ?? 'Personal';

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.symmetric(
        horizontal: MonoPulseSpacing.lg,
        vertical: MonoPulseSpacing.md,
      ),
      decoration: BoxDecoration(
        color: MonoPulseColors.surface,
        borderRadius: BorderRadius.circular(MonoPulseRadius.large),
        border: Border.all(color: MonoPulseColors.borderSubtle),
      ),
      child: Row(
        children: [
          const Icon(Icons.music_note, color: MonoPulseColors.accentOrange),
          const SizedBox(width: MonoPulseSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MonoPulseTypography.bodyMedium.copyWith(
                    color: MonoPulseColors.textHighEmphasis,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  setlist == null
                      ? '${song.artist} • $sourceLabel'
                      : '${setlist!.name} • $position / $total • $sourceLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MonoPulseTypography.bodySmall.copyWith(
                    color: MonoPulseColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Clear loaded song',
            onPressed: onClear,
            icon: const Icon(
              Icons.close,
              color: MonoPulseColors.textSecondary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

enum _LibraryTab { songs, setlists }

class _SongLibrarySheet extends ConsumerStatefulWidget {
  const _SongLibrarySheet({
    required this.onLoadSong,
    required this.onLoadSetlist,
  });

  final void Function(Song song, String? bandId) onLoadSong;
  final void Function(Setlist setlist, List<Song> songs, String? bandId)
  onLoadSetlist;

  @override
  ConsumerState<_SongLibrarySheet> createState() => _SongLibrarySheetState();
}

class _SongLibrarySheetState extends ConsumerState<_SongLibrarySheet> {
  _LibraryTab _tab = _LibraryTab.songs;
  String? _bandId;

  @override
  Widget build(BuildContext context) {
    final bandsAsync = ref.watch(bandsProvider);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        decoration: const BoxDecoration(
          color: MonoPulseColors.surfaceRaised,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(MonoPulseRadius.massive),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: MonoPulseSpacing.md),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: MonoPulseColors.borderDefault,
                borderRadius: BorderRadius.circular(MonoPulseRadius.small),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(MonoPulseSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Songs & Setlists',
                      style: MonoPulseTypography.headlineSmall.copyWith(
                        color: MonoPulseColors.textHighEmphasis,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: MonoPulseColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MonoPulseSpacing.lg,
              ),
              child: Row(
                children: _LibraryTab.values
                    .map(
                      (tab) => Expanded(
                        child: _LibraryTabButton(
                          label: tab == _LibraryTab.songs
                              ? 'Songs'
                              : 'Setlists',
                          icon: tab == _LibraryTab.songs
                              ? Icons.music_note
                              : Icons.playlist_play,
                          selected: _tab == tab,
                          onTap: () => setState(() => _tab = tab),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MonoPulseSpacing.lg,
                MonoPulseSpacing.md,
                MonoPulseSpacing.lg,
                MonoPulseSpacing.sm,
              ),
              child: bandsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => _SourceDropdown(
                  bands: const [],
                  bandId: null,
                  onChanged: (_) {},
                ),
                data: (bands) => _SourceDropdown(
                  bands: bands,
                  bandId: _bandId,
                  onChanged: (value) => setState(() => _bandId = value),
                ),
              ),
            ),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final songsAsync = _bandId == null
        ? ref.watch(songsProvider)
        : ref.watch(bandSongsProvider(_bandId!));

    if (_tab == _LibraryTab.songs) {
      return _AsyncSongList(
        songsAsync: songsAsync,
        onRetry: () => _bandId == null
            ? ref.invalidate(songsProvider)
            : ref.invalidate(bandSongsProvider(_bandId!)),
        onTap: (song) => widget.onLoadSong(song, _bandId),
      );
    }

    final setlistsAsync = _bandId == null
        ? ref.watch(setlistsProvider)
        : ref.watch(bandSetlistsProvider(_bandId!));
    return _AsyncSetlistList(
      setlistsAsync: setlistsAsync,
      onRetry: () => _bandId == null
          ? ref.invalidate(setlistsProvider)
          : ref.invalidate(bandSetlistsProvider(_bandId!)),
      onTap: (setlist) {
        final songs = songsAsync.value ?? const <Song>[];
        widget.onLoadSetlist(setlist, songs, _bandId);
      },
    );
  }
}

class _LibraryTabButton extends StatelessWidget {
  const _LibraryTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: MonoPulseSpacing.md),
          decoration: BoxDecoration(
            color: selected
                ? MonoPulseColors.accentOrange.withValues(alpha: 0.16)
                : MonoPulseColors.blackElevated,
            border: Border(
              bottom: BorderSide(
                color: selected
                    ? MonoPulseColors.accentOrange
                    : MonoPulseColors.borderSubtle,
                width: selected ? 2 : 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected
                    ? MonoPulseColors.accentOrange
                    : MonoPulseColors.textSecondary,
              ),
              const SizedBox(width: MonoPulseSpacing.sm),
              Text(
                label,
                style: MonoPulseTypography.labelLarge.copyWith(
                  color: selected
                      ? MonoPulseColors.accentOrange
                      : MonoPulseColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceDropdown extends StatelessWidget {
  const _SourceDropdown({
    required this.bands,
    required this.bandId,
    required this.onChanged,
  });

  final List<Band> bands;
  final String? bandId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: bandId,
      dropdownColor: MonoPulseColors.surfaceRaised,
      decoration: const InputDecoration(
        labelText: 'Library source',
        prefixIcon: Icon(Icons.folder_outlined),
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Personal')),
        ...bands.map(
          (band) =>
              DropdownMenuItem<String?>(value: band.id, child: Text(band.name)),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _AsyncSongList extends StatelessWidget {
  const _AsyncSongList({
    required this.songsAsync,
    required this.onRetry,
    required this.onTap,
  });

  final AsyncValue<List<Song>> songsAsync;
  final VoidCallback onRetry;
  final ValueChanged<Song> onTap;

  @override
  Widget build(BuildContext context) {
    return songsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: ErrorBanner.card(
          message: 'Failed to load songs: $error',
          onRetry: onRetry,
        ),
      ),
      data: (songs) => songs.isEmpty
          ? const _EmptyLibraryState(
              icon: Icons.music_note_outlined,
              label: 'No songs yet',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(MonoPulseSpacing.lg),
              itemCount: songs.length,
              itemBuilder: (context, index) => _SongCard(
                song: songs[index],
                onTap: () => onTap(songs[index]),
              ),
            ),
    );
  }
}

class _AsyncSetlistList extends StatelessWidget {
  const _AsyncSetlistList({
    required this.setlistsAsync,
    required this.onRetry,
    required this.onTap,
  });

  final AsyncValue<List<Setlist>> setlistsAsync;
  final VoidCallback onRetry;
  final ValueChanged<Setlist> onTap;

  @override
  Widget build(BuildContext context) {
    return setlistsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: ErrorBanner.card(
          message: 'Failed to load setlists: $error',
          onRetry: onRetry,
        ),
      ),
      data: (setlists) => setlists.isEmpty
          ? const _EmptyLibraryState(
              icon: Icons.playlist_play_outlined,
              label: 'No setlists yet',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(MonoPulseSpacing.lg),
              itemCount: setlists.length,
              itemBuilder: (context, index) => _SetlistCard(
                setlist: setlists[index],
                onTap: () => onTap(setlists[index]),
              ),
            ),
    );
  }
}

class _EmptyLibraryState extends StatelessWidget {
  const _EmptyLibraryState({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: MonoPulseColors.textDisabled, size: 48),
          const SizedBox(height: MonoPulseSpacing.md),
          Text(
            label,
            style: MonoPulseTypography.bodyLarge.copyWith(
              color: MonoPulseColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SongCard extends StatelessWidget {
  const _SongCard({required this.song, required this.onTap});

  final Song song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bpm = song.ourBPM ?? song.originalBPM;
    return Card(
      color: MonoPulseColors.blackElevated,
      child: ListTile(
        onTap: onTap,
        leading: const Icon(
          Icons.music_note,
          color: MonoPulseColors.accentOrange,
        ),
        title: Text(song.title),
        subtitle: Text(song.artist),
        trailing: bpm == null ? null : Text('$bpm BPM'),
      ),
    );
  }
}

class _SetlistCard extends StatelessWidget {
  const _SetlistCard({required this.setlist, required this.onTap});

  final Setlist setlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = setlist.songIds.length;
    return Card(
      color: MonoPulseColors.blackElevated,
      child: ListTile(
        onTap: onTap,
        leading: const Icon(
          Icons.playlist_play,
          color: MonoPulseColors.accentOrange,
        ),
        title: Text(setlist.name),
        subtitle: Text(
          setlist.description?.isNotEmpty == true
              ? '${setlist.description} • $count ${count == 1 ? 'song' : 'songs'}'
              : '$count ${count == 1 ? 'song' : 'songs'}',
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
