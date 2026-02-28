import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../widgets/tools/tool_scaffold.dart';
import '../widgets/metronome/time_signature_block.dart';
import '../widgets/metronome/central_tempo_circle.dart';
import '../widgets/metronome/fine_adjustment_buttons.dart';
import '../widgets/metronome/song_library_block.dart';
import '../widgets/metronome/bottom_transport_bar.dart';
import '../../models/song.dart';
import '../../models/metronome_state.dart';
import '../../services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/data/metronome_provider.dart';

/// Metronome Screen - ToolScreenScaffold Migration (Sprint 5)
///
/// Migrated to use ToolScreenScaffold for consistent tool screen structure:
/// - ToolAppBar with back button, title, three dots menu
/// - Main content: Time Signature + Central Tempo Circle
/// - Secondary: Fine Adjustment Buttons
/// - Bottom: Transport Bar + Song Library
/// - Standard PopupMenu for menu items
///
/// Screen Structure (Top to Bottom):
/// 1. ToolAppBar (~56px) - Back arrow, title, three dots menu
/// 2. Time Signature Block (~80-100px) - Accents + beats with +/- buttons
/// 3. Central Tempo Circle (50-60% screen width) - Rotary dial
/// 4. Fine Adjustment Buttons - +1/-1, +5/-5, +10/-10
/// 5. Bottom Transport Bar (64-80px) - Play/Pause, Previous/Next
/// 6. Song Library Block - Compact pill + expanded panel
class MetronomeScreen extends ConsumerStatefulWidget {
  const MetronomeScreen({super.key});

  @override
  ConsumerState<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends ConsumerState<MetronomeScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(metronomeProvider);
    final metronome = ref.watch(metronomeProvider.notifier);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ToolScreenScaffold(
        title: 'Metronome',
        menuItems: _buildMenuItems(context, metronome, state),
        mainWidget: _buildMainContent(context),
        secondaryWidget: const FineAdjustmentButtons(),
        bottomWidget: _buildBottomContent(),
        showOfflineIndicator: true,
      ),
    );
  }

  /// Builds the main content area with Time Signature and Central Tempo Circle
  Widget _buildMainContent(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 375;

    return Column(
      children: [
        // Air gap after AppBar
        SizedBox(height: isSmallScreen ? 16 : 24),

        // Time Signature Block
        const TimeSignatureBlock(),

        // Air gap
        SizedBox(height: isSmallScreen ? 16 : 24),

        // Central Tempo Circle (takes remaining space)
        const Expanded(child: CentralTempoCircle()),
      ],
    );
  }

  /// Builds the bottom content with Transport Bar and Song Library
  Widget _buildBottomContent() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bottom Transport Bar
        BottomTransportBar(),

        // Air gap
        SizedBox(height: 16),

        // Song Library Block
        SongLibraryBlock(),

        // Bottom padding for SafeArea
        SizedBox(height: 24),
      ],
    );
  }

  /// Builds menu items for the three dots menu
  List<PopupMenuItem<void>> _buildMenuItems(
    BuildContext context,
    MetronomeNotifier metronome,
    MetronomeState state,
  ) {
    final items = <PopupMenuItem<void>>[];

    // Save to Song (only shown when song is loaded)
    if (state.loadedSong != null) {
      items.add(
        PopupMenuItem<void>(
          child: Row(
            children: [
              const Icon(
                Icons.save_outlined,
                color: MonoPulseColors.accentOrange,
                size: 20,
              ),
              const SizedBox(width: MonoPulseSpacing.md),
              Expanded(
                child: Text(
                  "Save to '${state.loadedSong!.title}'",
                  style: MonoPulseTypography.bodyMedium.copyWith(
                    color: MonoPulseColors.textHighEmphasis,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          onTap: () => _saveMetronomeToSong(context, metronome, state),
        ),
      );
    }

    // Save New Song
    items.add(
      PopupMenuItem<void>(
        child: Row(
          children: [
            const Icon(
              Icons.add_circle_outline,
              color: MonoPulseColors.accentOrange,
              size: 20,
            ),
            const SizedBox(width: MonoPulseSpacing.md),
            Text(
              'Save New Song',
              style: MonoPulseTypography.bodyMedium.copyWith(
                color: MonoPulseColors.textHighEmphasis,
              ),
            ),
          ],
        ),
        onTap: () => _navigateToSaveSong(context, metronome, state.bpm),
      ),
    );

    // Update Song
    items.add(
      PopupMenuItem<void>(
        child: Row(
          children: [
            const Icon(
              Icons.edit_note_outlined,
              color: MonoPulseColors.accentOrange,
              size: 20,
            ),
            const SizedBox(width: MonoPulseSpacing.md),
            Expanded(
              child: Text(
                state.loadedSong != null
                    ? "Update '${state.loadedSong!.title}'"
                    : 'Update Song',
                style: MonoPulseTypography.bodyMedium.copyWith(
                  color: MonoPulseColors.textHighEmphasis,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        onTap: () => _navigateToUpdateSong(context, metronome, state),
      ),
    );

    return items;
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
