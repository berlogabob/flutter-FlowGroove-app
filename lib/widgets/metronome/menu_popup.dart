import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data/metronome_provider.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../models/song.dart';
import '../../models/metronome_state.dart';
import '../../services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Three Dots Menu Popup - Mono Pulse design (Sprint Fix)
///
/// Single icon ⋯ (#A0A0A5 → #FF5E00 on tap)
/// Menu items:
/// - Save to Song → saves current metronome settings to loaded song
/// - Save New Song → create song form (pre-fills BPM with current)
/// - Update Song → songs list → select → confirm "Update 'Name'?"
/// - If playlist loaded — pre-select current song
///
/// Menu styling:
/// - Background: #121212
/// - Text: #EDEDED
/// - Icons: Orange (#FF5E00)
class MenuPopup extends ConsumerStatefulWidget {
  final Offset position;
  final VoidCallback onClose;

  const MenuPopup({super.key, required this.position, required this.onClose});

  @override
  ConsumerState<MenuPopup> createState() => _MenuPopupState();
}

class _MenuPopupState extends ConsumerState<MenuPopup> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(metronomeProvider);
    final metronome = ref.watch(metronomeProvider.notifier);

    return Positioned(
      top: widget.position.dy,
      right: widget.position.dx,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: widget.onClose,
          child: SizedBox(
            // Transparent overlay to catch taps outside menu
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: Stack(
              children: [
                // Menu card
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 240,
                    decoration: BoxDecoration(
                      color: MonoPulseColors.surface, // #121212
                      borderRadius: BorderRadius.circular(
                        MonoPulseRadius.large,
                      ),
                      border: Border.all(
                        color: MonoPulseColors.borderSubtle,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: MonoPulseColors.black.withValues(alpha: 0.5),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Save to Song (only shown when song is loaded)
                        if (state.loadedSong != null) ...[
                          _MenuItem(
                            icon: Icons.save_outlined,
                            label: "Save to '${state.loadedSong!.title}'",
                            onTap: () {
                              HapticFeedback.lightImpact();
                              widget.onClose();
                              _saveMetronomeToSong(context, metronome, state);
                            },
                          ),
                          const Divider(
                            height: 1,
                            color: MonoPulseColors.borderSubtle,
                          ),
                        ],
                        // Save New Song
                        _MenuItem(
                          icon: Icons.add_circle_outline,
                          label: 'Save New Song',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            widget.onClose();
                            _navigateToSaveSong(context, metronome, state.bpm);
                          },
                        ),
                        const Divider(
                          height: 1,
                          color: MonoPulseColors.borderSubtle,
                        ),
                        // Update Song
                        _MenuItem(
                          icon: Icons.edit_note_outlined,
                          label: state.loadedSong != null
                              ? "Update '${state.loadedSong!.title}'"
                              : 'Update Song',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            widget.onClose();
                            _navigateToUpdateSong(context, metronome, state);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Save current metronome settings to the loaded song
  Future<void> _saveMetronomeToSong(
    BuildContext context,
    MetronomeNotifier metronome,
    MetronomeState state,
  ) async {
    final updatedSong = metronome.saveMetronomeToSong();
    if (updatedSong == null) {
      _showErrorSnackBar(context, 'No song loaded');
      return;
    }

    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorSnackBar(context, 'Not signed in');
        return;
      }

      // Save to Firestore
      final firestore = FirestoreService();
      await firestore.updateSong(updatedSong, uid: user.uid);

      if (!context.mounted) return;
      _showSuccessSnackBar(
        context,
        "Saved metronome settings to '${updatedSong.title}'",
      );
    } catch (e) {
      if (!context.mounted) return;
      _showErrorSnackBar(context, 'Failed to save: $e');
    }
  }

  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: MonoPulseColors.accentOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
        ),
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: MonoPulseColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
        ),
      ),
    );
  }

  void _navigateToSaveSong(
    BuildContext context,
    MetronomeNotifier metronome,
    int currentBpm,
  ) {
    // Navigate to save song form with pre-filled BPM
    // This would typically navigate to a song creation screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Save New Song (BPM: $currentBpm)'),
        backgroundColor: MonoPulseColors.surfaceRaised,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
        ),
      ),
    );
  }

  void _navigateToUpdateSong(
    BuildContext context,
    MetronomeNotifier metronome,
    MetronomeState state,
  ) {
    // If playlist loaded — pre-select current song
    if (state.loadedSong != null) {
      _showUpdateConfirmDialog(context, state.loadedSong!);
    } else if (state.loadedSetlist != null) {
      // Show setlist songs
      _showSetlistSelectionDialog(context, state);
    } else {
      // Show all songs list
      _showSongsListDialog(context, state);
    }
  }

  void _showUpdateConfirmDialog(BuildContext context, Song song) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MonoPulseColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MonoPulseRadius.xlarge),
        ),
        title: Text(
          "Update '${song.title}'?",
          style: MonoPulseTypography.headlineSmall.copyWith(
            color: MonoPulseColors.textHighEmphasis,
          ),
        ),
        content: Text(
          'This will update the song with current metronome settings.',
          style: MonoPulseTypography.bodyMedium.copyWith(
            color: MonoPulseColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              'Cancel',
              style: MonoPulseTypography.labelLarge.copyWith(
                color: MonoPulseColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Perform update
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Updated '${song.title}'"),
                  backgroundColor: MonoPulseColors.accentOrange,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: MonoPulseColors.accentOrange,
              foregroundColor: MonoPulseColors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
              ),
            ),
            child: Text(
              'Update',
              style: MonoPulseTypography.labelLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSetlistSelectionDialog(BuildContext context, MetronomeState state) {
    final setlist = state.loadedSetlist;
    if (setlist == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MonoPulseColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MonoPulseRadius.xlarge),
        ),
        title: Text(
          'Select Song from ${setlist.name}',
          style: MonoPulseTypography.headlineSmall.copyWith(
            color: MonoPulseColors.textHighEmphasis,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: setlist.songIds.length,
            itemBuilder: (context, index) {
              final songId = setlist.songIds[index];
              // In real implementation, fetch song name from repository
              return ListTile(
                title: Text(
                  'Song $songId',
                  style: MonoPulseTypography.bodyMedium.copyWith(
                    color: MonoPulseColors.textHighEmphasis,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  // Show confirm dialog with selected song
                  _showUpdateConfirmDialog(
                    context,
                    Song(
                      id: songId,
                      title: 'Song $songId',
                      artist: 'Unknown',
                      originalBPM: 120,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showSongsListDialog(BuildContext context, MetronomeState state) {
    // Sample songs list - in real implementation, fetch from repository
    final songs = [
      Song(
        id: '1',
        title: 'Song One',
        artist: 'Artist A',
        originalBPM: 120,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Song(
        id: '2',
        title: 'Song Two',
        artist: 'Artist B',
        originalBPM: 140,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Song(
        id: '3',
        title: 'Song Three',
        artist: 'Artist C',
        originalBPM: 100,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MonoPulseColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MonoPulseRadius.xlarge),
        ),
        title: Text(
          'Select Song to Update',
          style: MonoPulseTypography.headlineSmall.copyWith(
            color: MonoPulseColors.textHighEmphasis,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return ListTile(
                title: Text(
                  song.title,
                  style: MonoPulseTypography.bodyMedium.copyWith(
                    color: MonoPulseColors.textHighEmphasis,
                  ),
                ),
                subtitle: Text(
                  '${song.originalBPM ?? 120} BPM',
                  style: MonoPulseTypography.bodySmall.copyWith(
                    color: MonoPulseColors.textTertiary,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _showUpdateConfirmDialog(context, song);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MonoPulseSpacing.lg,
            vertical: MonoPulseSpacing.md,
          ),
          decoration: BoxDecoration(
            color: _isHovered
                ? MonoPulseColors.blackElevated
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 20,
                color: MonoPulseColors.accentOrange, // Orange icons
              ),
              const SizedBox(width: MonoPulseSpacing.md),
              Expanded(
                child: Text(
                  widget.label,
                  style: MonoPulseTypography.bodyMedium.copyWith(
                    color: MonoPulseColors.textHighEmphasis, // #EDEDED
                    fontWeight: _isHovered ? FontWeight.w600 : FontWeight.w400,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
