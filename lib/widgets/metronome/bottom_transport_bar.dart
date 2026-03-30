/// Bottom transport bar widget
///
/// Main transport controls for metronome.
/// Features:
/// - Play/pause button with pulse animation
/// - Setlist navigation (previous/next)
/// - Loaded song/setlist display
/// - Large touch targets
/// - Visual feedback
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data/metronome_provider.dart';
import '../../providers/metronome_selective_providers.dart';

/// Bottom transport bar with play/pause and navigation
class BottomTransportBar extends ConsumerWidget {
  const BottomTransportBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(metronomeProvider);
    final notifier = ref.read(metronomeProvider.notifier);
    final loadedSong = ref.watch(metronomeLoadedSongProvider);
    final loadedSetlist = ref.watch(metronomeLoadedSetlistProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          _PlayPauseButton(
            isPlaying: state.isPlaying,
            onTap: notifier.toggle,
          ),

          const SizedBox(height: 16),

          // Loaded content display
          if (loadedSong != null || loadedSetlist != null) ...[
            _LoadedContentDisplay(
              song: loadedSong,
              setlist: loadedSetlist,
              currentIndex: state.currentSetlistIndex,
            ),
            const SizedBox(height: 12),
          ],

          // Setlist navigation
          if (loadedSetlist != null) ...[
            _SetlistNavigation(
              currentIndex: state.currentSetlistIndex,
              totalSongs: loadedSetlist.songIds.length,
              onPrevious: notifier.previousSetlistSong,
              onNext: notifier.nextSetlistSong,
            ),
          ],
        ],
      ),
    );
  }
}

/// Play/pause button with pulse animation
class _PlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.onTap,
  });

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _pulseController.forward(from: 0.0);
        widget.onTap();
        HapticFeedback.mediumImpact();
      },
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isPlaying
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.primaryContainer,
                boxShadow: widget.isPlaying
                    ? [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                widget.isPlaying ? Icons.pause : Icons.play_arrow,
                color: widget.isPlaying
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onPrimaryContainer,
                size: 48,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Display for loaded song/setlist info
class _LoadedContentDisplay extends StatelessWidget {
  final dynamic song;
  final dynamic setlist;
  final int currentIndex;

  const _LoadedContentDisplay({
    this.song,
    this.setlist,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    String title;
    String subtitle;

    if (song != null) {
      title = (song as dynamic).title as String? ?? 'Unknown';
      subtitle = (song as dynamic).artist as String? ?? '';
    } else if (setlist != null &&
        (setlist as dynamic).songIds is List &&
        ((setlist as dynamic).songIds as List).isNotEmpty &&
        currentIndex < ((setlist as dynamic).songIds as List).length) {
      // For now, just show setlist info
      title = 'Setlist: ${(setlist as dynamic).name as String? ?? "Unnamed"}';
      subtitle = 'Song ${currentIndex + 1} of ${((setlist as dynamic).songIds as List).length}';
    } else {
      title = 'No song loaded';
      subtitle = '';
    }

    return Row(
      children: [
        Icon(
          Icons.music_note,
          color: Theme.of(context).colorScheme.primary,
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Setlist navigation controls
class _SetlistNavigation extends StatelessWidget {
  final int currentIndex;
  final int totalSongs;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _SetlistNavigation({
    required this.currentIndex,
    required this.totalSongs,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final canGoPrevious = currentIndex > 0;
    final canGoNext = currentIndex < totalSongs - 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous),
          onPressed: canGoPrevious ? onPrevious : null,
          tooltip: 'Previous Song',
          color: canGoPrevious
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
        ),
        Text(
          '${currentIndex + 1} / $totalSongs',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next),
          onPressed: canGoNext ? onNext : null,
          tooltip: 'Next Song',
          color: canGoNext
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
        ),
      ],
    );
  }
}
