import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data/metronome_provider.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../models/song.dart';
import '../../models/setlist.dart';

/// Song Library Block widget - Mono Pulse design
///
/// Compact view: pill (radius 20px, background #121212)
/// - Text "Song library" 16px Medium #EDEDED
/// - Note icon left #A0A0A5
///
/// Expanded view (tap compact): Slide-up panel from bottom
/// - Background #1A1A1A, 24px top radius
/// - "Song Library" section: user/band songs
/// - "Setlist Library" section: setlists with navigation
class SongLibraryBlock extends ConsumerStatefulWidget {
  const SongLibraryBlock({super.key});

  @override
  ConsumerState<SongLibraryBlock> createState() => _SongLibraryBlockState();
}

class _SongLibraryBlockState extends ConsumerState<SongLibraryBlock> {
  bool _isExpanded = false;
  bool _showSetlists = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(metronomeProvider);
    final metronome = ref.watch(metronomeProvider.notifier);

    return Column(
      children: [
        // Compact pill button
        if (!_isExpanded)
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _isExpanded = true);
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
                  Icon(
                    Icons.music_note_outlined,
                    color: MonoPulseColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: MonoPulseSpacing.md),
                  Text(
                    'Song Library',
                    style: MonoPulseTypography.bodyLarge.copyWith(
                      color: MonoPulseColors.textHighEmphasis,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Loaded content indicator
        if (!_isExpanded &&
            (state.loadedSong != null || state.loadedSetlist != null))
          Padding(
            padding: const EdgeInsets.only(top: MonoPulseSpacing.md),
            child: Text(
              state.loadedSong != null
                  ? 'Loaded: ${state.loadedSong!.title}'
                  : 'Loaded: ${state.loadedSetlist!.name} (${state.currentSetlistIndex + 1}/${state.loadedSetlist!.songIds.length})',
              style: MonoPulseTypography.bodySmall.copyWith(
                color: MonoPulseColors.textTertiary,
              ),
            ),
          ),

        // Slide-up panel
        if (_isExpanded)
          _SlideUpPanel(
            showSetlists: _showSetlists,
            onToggleView: () {
              HapticFeedback.lightImpact();
              setState(() => _showSetlists = !_showSetlists);
            },
            onClose: () {
              HapticFeedback.lightImpact();
              setState(() => _isExpanded = false);
            },
            onLoadSong: (song) {
              HapticFeedback.mediumImpact();
              metronome.loadSongTempo(song);
              setState(() => _isExpanded = false);
            },
            onLoadSetlist: (setlist) {
              HapticFeedback.mediumImpact();
              metronome.loadSetlistQueue(setlist);
              setState(() => _isExpanded = false);
            },
          ),
      ],
    );
  }
}

class _SlideUpPanel extends StatelessWidget {
  final bool showSetlists;
  final VoidCallback onToggleView;
  final VoidCallback onClose;
  final Function(Song) onLoadSong;
  final Function(Setlist) onLoadSetlist;

  const _SlideUpPanel({
    required this.showSetlists,
    required this.onToggleView,
    required this.onClose,
    required this.onLoadSong,
    required this.onLoadSetlist,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Backdrop
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: Container(
              color: MonoPulseColors.black.withValues(alpha: 0.7),
            ),
          ),
        ),

        // Panel
        Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedContainer(
            duration: MonoPulseAnimation.durationMedium,
            curve: MonoPulseAnimation.curveCustom,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            decoration: BoxDecoration(
              color: MonoPulseColors.surfaceRaised,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(MonoPulseRadius.massive),
              ),
            ),
            child: Column(
              children: [
                // Handle bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: MonoPulseSpacing.lg,
                  ),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MonoPulseColors.borderDefault,
                      borderRadius: BorderRadius.circular(
                        MonoPulseRadius.small,
                      ),
                    ),
                  ),
                ),

                // Header with tabs
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MonoPulseSpacing.xxl,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Tab toggle
                      GestureDetector(
                        onTap: onToggleView,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: MonoPulseSpacing.lg,
                            vertical: MonoPulseSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: MonoPulseColors.blackElevated,
                            borderRadius: BorderRadius.circular(
                              MonoPulseRadius.huge,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                showSetlists
                                    ? Icons.playlist_play
                                    : Icons.music_note,
                                color: MonoPulseColors.accentOrange,
                                size: 18,
                              ),
                              const SizedBox(width: MonoPulseSpacing.sm),
                              Text(
                                showSetlists ? 'Setlists' : 'Songs',
                                style: MonoPulseTypography.labelLarge.copyWith(
                                  color: MonoPulseColors.accentOrange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Close button
                      GestureDetector(
                        onTap: onClose,
                        child: Container(
                          padding: const EdgeInsets.all(MonoPulseSpacing.sm),
                          decoration: BoxDecoration(
                            color: MonoPulseColors.blackElevated,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            color: MonoPulseColors.textSecondary,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: MonoPulseSpacing.lg),

                // Content
                Expanded(
                  child: showSetlists
                      ? _SetlistList(onLoadSetlist: onLoadSetlist)
                      : _SongList(onLoadSong: onLoadSong),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SongList extends StatelessWidget {
  final Function(Song) onLoadSong;

  const _SongList({required this.onLoadSong});

  @override
  Widget build(BuildContext context) {
    // Placeholder - in real app, fetch from provider
    final songs = _getSampleSongs();

    if (songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note_outlined,
              color: MonoPulseColors.textDisabled,
              size: 48,
            ),
            const SizedBox(height: MonoPulseSpacing.md),
            Text(
              'No songs yet',
              style: MonoPulseTypography.bodyLarge.copyWith(
                color: MonoPulseColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: MonoPulseSpacing.xxl,
        vertical: MonoPulseSpacing.sm,
      ),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        return _SongCard(song: song, onTap: () => onLoadSong(song));
      },
    );
  }

  List<Song> _getSampleSongs() {
    // Sample data - replace with actual data from provider
    return [
      Song(
        id: '1',
        title: 'Wonderwall',
        artist: 'Oasis',
        originalBPM: 87,
        ourBPM: 87,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Song(
        id: '2',
        title: 'Sweet Child O\' Mine',
        artist: 'Guns N\' Roses',
        originalBPM: 125,
        ourBPM: 125,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Song(
        id: '3',
        title: 'Hotel California',
        artist: 'Eagles',
        originalBPM: 75,
        ourBPM: 75,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
  }
}

class _SongCard extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;

  const _SongCard({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bpm = song.ourBPM ?? song.originalBPM;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: MonoPulseSpacing.md),
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        decoration: BoxDecoration(
          color: MonoPulseColors.blackElevated,
          borderRadius: BorderRadius.circular(MonoPulseRadius.large),
          border: Border.all(color: MonoPulseColors.borderSubtle),
        ),
        child: Row(
          children: [
            // Note icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: MonoPulseColors.accentOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
              ),
              child: Icon(
                Icons.music_note,
                color: MonoPulseColors.accentOrange,
                size: 20,
              ),
            ),
            const SizedBox(width: MonoPulseSpacing.md),

            // Song info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: MonoPulseTypography.bodyLarge.copyWith(
                      color: MonoPulseColors.textHighEmphasis,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    song.artist,
                    style: MonoPulseTypography.bodySmall.copyWith(
                      color: MonoPulseColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // BPM badge
            if (bpm != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MonoPulseSpacing.md,
                  vertical: MonoPulseSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: MonoPulseColors.accentOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
                ),
                child: Text(
                  '$bpm BPM',
                  style: MonoPulseTypography.labelMedium.copyWith(
                    color: MonoPulseColors.accentOrange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            const SizedBox(width: MonoPulseSpacing.sm),
            Icon(
              Icons.chevron_right,
              color: MonoPulseColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _SetlistList extends StatelessWidget {
  final Function(Setlist) onLoadSetlist;

  const _SetlistList({required this.onLoadSetlist});

  @override
  Widget build(BuildContext context) {
    // Placeholder - in real app, fetch from provider
    final setlists = _getSampleSetlists();

    if (setlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.playlist_play_outlined,
              color: MonoPulseColors.textDisabled,
              size: 48,
            ),
            const SizedBox(height: MonoPulseSpacing.md),
            Text(
              'No setlists yet',
              style: MonoPulseTypography.bodyLarge.copyWith(
                color: MonoPulseColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: MonoPulseSpacing.xxl,
        vertical: MonoPulseSpacing.sm,
      ),
      itemCount: setlists.length,
      itemBuilder: (context, index) {
        final setlist = setlists[index];
        return _SetlistCard(
          setlist: setlist,
          onTap: () => onLoadSetlist(setlist),
        );
      },
    );
  }

  List<Setlist> _getSampleSetlists() {
    // Sample data - replace with actual data from provider
    return [
      Setlist(
        id: '1',
        bandId: 'band1',
        name: 'Summer Tour 2026',
        description: 'Main setlist for summer shows',
        songIds: ['1', '2', '3', '4', '5'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Setlist(
        id: '2',
        bandId: 'band1',
        name: 'Acoustic Set',
        description: 'Unplugged performance',
        songIds: ['6', '7', '8'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
  }
}

class _SetlistCard extends StatelessWidget {
  final Setlist setlist;
  final VoidCallback onTap;

  const _SetlistCard({required this.setlist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: MonoPulseSpacing.md),
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        decoration: BoxDecoration(
          color: MonoPulseColors.blackElevated,
          borderRadius: BorderRadius.circular(MonoPulseRadius.large),
          border: Border.all(color: MonoPulseColors.borderSubtle),
        ),
        child: Row(
          children: [
            // Playlist icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: MonoPulseColors.accentOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
              ),
              child: Icon(
                Icons.playlist_play,
                color: MonoPulseColors.accentOrange,
                size: 20,
              ),
            ),
            const SizedBox(width: MonoPulseSpacing.md),

            // Setlist info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    setlist.name,
                    style: MonoPulseTypography.bodyLarge.copyWith(
                      color: MonoPulseColors.textHighEmphasis,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (setlist.description != null &&
                      setlist.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      setlist.description!,
                      style: MonoPulseTypography.bodySmall.copyWith(
                        color: MonoPulseColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${setlist.songIds.length} songs',
                    style: MonoPulseTypography.bodySmall.copyWith(
                      color: MonoPulseColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: MonoPulseSpacing.sm),
            Icon(
              Icons.chevron_right,
              color: MonoPulseColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
