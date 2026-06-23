import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/band.dart';
import '../../models/metronome_state.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/data/metronome_provider.dart';
import '../../router/app_router.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../widgets/tools/tool_scaffold.dart';
import '../../widgets/tools/tool_transport_bar.dart';
import '../widgets/metronome/metronome_sheets.dart';
import '../widgets/metronome/song_library_block.dart';
import '../widgets/metronome/tempo_control_cluster.dart';
import '../widgets/metronome/time_signature_block.dart';
import 'concert_mode_screen.dart';
import 'songs/models/song_form_data.dart';

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

class _MetronomeScreenState extends ConsumerState<MetronomeScreen>
    with WidgetsBindingObserver {
  late final MetronomeNotifier _metronome;

  @override
  void initState() {
    super.initState();
    _metronome = ref.read(metronomeProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void deactivate() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _stopSafely());
    super.deactivate();
  }

  void _stopSafely() {
    try {
      _metronome.stop();
    } on Object {
      // The provider (or its Ref) may already be disposed along with its
      // enclosing ProviderScope during teardown; stopping is then a no-op.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _stopSafely();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(metronomeProvider);
    final metronome = ref.watch(metronomeProvider.notifier);
    var canEditSource = false;
    if (state.activeSong != null) {
      final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;
      if (state.sourceBandId == null) {
        canEditSource = userId != null;
      } else {
        final bands = ref.watch(bandsProvider).value ?? const <Band>[];
        final sourceBand = bands
            .where((band) => band.id == state.sourceBandId)
            .firstOrNull;
        final sourceMember = sourceBand?.members
            .where((member) => member.uid == userId)
            .firstOrNull;
        canEditSource =
            sourceMember?.role == BandMember.roleAdmin ||
            sourceMember?.role == BandMember.roleEditor;
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ToolScreenScaffold(
        title: 'Metronome',
        menuItems: _buildMenuItems(
          context,
          metronome,
          state,
          canEditSource: canEditSource,
        ),
        mainWidget: const _MetronomePerformanceSurface(),
      ),
    );
  }

  /// Builds menu items for the three dots menu
  List<PopupMenuEntry<dynamic>> _buildMenuItems(
    BuildContext context,
    MetronomeNotifier metronome,
    MetronomeState state, {
    required bool canEditSource,
  }) {
    final items = <PopupMenuEntry<dynamic>>[];

    // Concert Mode — full-screen stage view (Mono Pulse).
    items.add(
      PopupMenuItem<void>(
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => const ConcertModeScreen(),
            fullscreenDialog: true,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.theaters_outlined,
              color: MonoPulseColors.accentOrange,
              size: 20,
            ),
            const SizedBox(width: MonoPulseSpacing.md),
            Expanded(
              child: Text(
                'Concert Mode',
                style: MonoPulseTypography.bodyMedium.copyWith(
                  color: MonoPulseColors.textHighEmphasis,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    items.add(const PopupMenuDivider(height: 1));

    // Sound / Count-in / Ramp live here instead of on the main screen, so the
    // metronome stays clean (Mono Pulse: "main window stays clean").
    PopupMenuItem<void> settingRow({
      required IconData icon,
      required String label,
      required String trailing,
      required bool active,
      required VoidCallback onTap,
    }) {
      return PopupMenuItem<void>(
        onTap: onTap,
        child: Row(
          children: [
            Icon(
              icon,
              color: active
                  ? MonoPulseColors.accentOrange
                  : MonoPulseColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: MonoPulseSpacing.md),
            Expanded(
              child: Text(
                label,
                style: MonoPulseTypography.bodyMedium.copyWith(
                  color: MonoPulseColors.textHighEmphasis,
                ),
              ),
            ),
            Text(
              trailing,
              style: MonoPulseTypography.labelMedium.copyWith(
                color: active
                    ? MonoPulseColors.accentOrange
                    : MonoPulseColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    items.add(
      settingRow(
        icon: Icons.graphic_eq,
        label: 'Sound',
        trailing: 'Click ›',
        active: false,
        onTap: () => showSoundSheet(context),
      ),
    );

    items.add(const PopupMenuDivider(height: 1));

    items.add(
      PopupMenuItem<void>(
        enabled: false,
        height: 28,
        child: Text(
          'PRACTICE',
          style: MonoPulseTypography.labelSmall.copyWith(
            color: MonoPulseColors.textTertiary,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    items.add(
      settingRow(
        icon: Icons.timer_outlined,
        label: 'Count-in',
        trailing: state.countInBars > 0 ? '${state.countInBars} bars ›' : 'Off ›',
        active: state.countInBars > 0,
        onTap: () => showCountInSheet(context),
      ),
    );

    items.add(
      settingRow(
        icon: Icons.trending_up,
        label: 'Ramp',
        trailing: state.activeTempoRamp != null ? 'On ›' : 'Off ›',
        active: state.activeTempoRamp != null,
        onTap: () => showRampSheet(context),
      ),
    );

    items.add(const PopupMenuDivider(height: 1));

    items.add(
      PopupMenuItem<void>(
        onTap: metronome.toggleHaptics,
        child: Row(
          children: [
            Icon(
              state.hapticsEnabled ? Icons.vibration : Icons.mobile_off,
              color: state.hapticsEnabled
                  ? MonoPulseColors.accentOrange
                  : MonoPulseColors.textTertiary,
              size: 20,
            ),
            const SizedBox(width: MonoPulseSpacing.md),
            Expanded(
              child: Text(
                'Haptics',
                style: MonoPulseTypography.bodyMedium.copyWith(
                  color: MonoPulseColors.textHighEmphasis,
                ),
              ),
            ),
            Text(
              state.hapticsEnabled ? 'On' : 'Off',
              style: MonoPulseTypography.labelMedium.copyWith(
                color: state.hapticsEnabled
                    ? MonoPulseColors.accentOrange
                    : MonoPulseColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    items.add(const PopupMenuDivider(height: 1));

    // Save to Song (only shown when song is loaded)
    if (state.activeSong != null) {
      items.add(
        PopupMenuItem<void>(
          enabled: canEditSource,
          onTap: canEditSource
              ? () => _navigateToEditSong(context, state)
              : null,
          child: Row(
            children: [
              const Icon(
                Icons.edit_outlined,
                color: MonoPulseColors.accentOrange,
                size: 20,
              ),
              const SizedBox(width: MonoPulseSpacing.md),
              Expanded(
                child: Text(
                  'Edit Song',
                  style: MonoPulseTypography.bodyMedium.copyWith(
                    color: MonoPulseColors.textHighEmphasis,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      items.add(
        PopupMenuItem<void>(
          enabled: canEditSource,
          onTap: canEditSource
              ? () => _saveMetronomeToSong(context, metronome, state)
              : null,
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
                  "Save to '${state.activeSong!.title}'",
                  style: MonoPulseTypography.bodyMedium.copyWith(
                    color: MonoPulseColors.textHighEmphasis,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Save New Song
    items.add(
      PopupMenuItem<void>(
        enabled: canEditSource,
        onTap: canEditSource ? () => _navigateToSaveSong(context, state) : null,
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
      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user == null) {
        _showErrorSnackBar(context, 'Not signed in');
        return;
      }

      final repository = ref.read(songRepositoryProvider);
      if (state.sourceBandId != null) {
        await repository.updateBandSong(updatedSong, state.sourceBandId!);
      } else {
        await repository.updateSong(updatedSong, uid: user.uid);
      }

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

  void _navigateToSaveSong(BuildContext context, MetronomeState state) {
    context.goAddSong(
      bandId: state.sourceBandId,
      initialFormData: SongFormData(
        ourBpm: state.bpm.toString(),
        accentBeats: state.accentBeats,
        regularBeats: state.regularBeats,
        beatModes: state.beatModes
            .map(List.of)
            .toList(growable: false),
      ),
    );
  }

  void _navigateToEditSong(BuildContext context, MetronomeState state) {
    final song = state.activeSong;
    if (song == null) return;

    context.pushNamed(
      'edit-song',
      pathParameters: {'id': song.id},
      extra: state.sourceBandId == null
          ? song
          : {'song': song, 'bandId': state.sourceBandId},
    );
  }
}

/// Adaptive metronome layout (Mono Pulse audit A6).
///
/// Portrait: a centered, max-width, scrollable column — phone fills the width,
/// web/tablet centers with gutters. Landscape: the dial moves to the left and
/// the beat map / transport / tools / library stack on the right, so the dial
/// no longer clips under the app bar on short heights.
class _MetronomePerformanceSurface extends StatelessWidget {
  const _MetronomePerformanceSurface();

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) => orientation == Orientation.landscape
          ? const _MetronomeLandscape()
          : const _MetronomePortrait(),
    );
  }
}

class _MetronomePortrait extends StatelessWidget {
  const _MetronomePortrait();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: const SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            MonoPulseSpacing.lg,
            MonoPulseSpacing.sm,
            MonoPulseSpacing.lg,
            MonoPulseSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TimeSignatureBlock(),
              SizedBox(height: MonoPulseSpacing.sm),
              TempoControlCluster(),
              SizedBox(height: MonoPulseSpacing.md),
              _MetronomeTransport(),
              SizedBox(height: MonoPulseSpacing.md),
              SongLibraryBlock(),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetronomeLandscape extends StatelessWidget {
  const _MetronomeLandscape();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: MonoPulseSpacing.lg,
        vertical: MonoPulseSpacing.sm,
      ),
      child: Row(
        children: [
          // Left: the dial, scaled to fit the available height.
          Expanded(
            child: Center(
              child: SingleChildScrollView(child: TempoControlCluster()),
            ),
          ),
          SizedBox(width: MonoPulseSpacing.xl),
          // Right: beat map, transport, tools, library.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TimeSignatureBlock(),
                  SizedBox(height: MonoPulseSpacing.sm),
                  _MetronomeTransport(),
                  SizedBox(height: MonoPulseSpacing.md),
                  SongLibraryBlock(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetronomeTransport extends ConsumerWidget {
  const _MetronomeTransport();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(metronomeProvider);
    final metronome = ref.read(metronomeProvider.notifier);
    final hasSetlist = state.loadedSetlist != null;

    return ToolTransportBar(
      isPlaying: state.isPlaying,
      onPlayPause: metronome.toggle,
      showNavigation: hasSetlist,
      onPrevious: state.canGoToPreviousSetlistSong
          ? metronome.previousSetlistSong
          : null,
      onNext: state.canGoToNextSetlistSong ? metronome.nextSetlistSong : null,
      margin: EdgeInsets.zero,
    );
  }
}


