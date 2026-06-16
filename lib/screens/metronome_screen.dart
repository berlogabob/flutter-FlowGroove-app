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

/// Single adaptive layout used on every screen size: a centered, max-width,
/// scrollable column. Phone fills the width; web/tablet centers with gutters.
/// Replaces the old compact/scroll/wide branches that hid features and
/// overflowed on the web.
class _MetronomePerformanceSurface extends StatelessWidget {
  const _MetronomePerformanceSurface();

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
              SizedBox(height: MonoPulseSpacing.sm),
              _MetronomeTransport(),
              SizedBox(height: MonoPulseSpacing.md),
              _MetronomeToolBar(),
              SizedBox(height: MonoPulseSpacing.sm),
              SongLibraryBlock(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row of tool chips opening the metronome's secondary panels as bottom sheets.
class _MetronomeToolBar extends ConsumerWidget {
  const _MetronomeToolBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countInBars = ref.watch(
      metronomeProvider.select((s) => s.countInBars),
    );
    final rampActive = ref.watch(
      metronomeProvider.select((s) => s.activeTempoRamp != null),
    );

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: MonoPulseSpacing.sm,
      runSpacing: MonoPulseSpacing.sm,
      children: [
        _ToolChip(
          icon: Icons.graphic_eq,
          label: 'Sound',
          onTap: () => showSoundSheet(context),
        ),
        _ToolChip(
          icon: Icons.timer_outlined,
          label: countInBars > 0 ? 'Count-in · $countInBars' : 'Count-in',
          active: countInBars > 0,
          onTap: () => showCountInSheet(context),
        ),
        _ToolChip(
          icon: Icons.trending_up,
          label: rampActive ? 'Ramp · on' : 'Ramp',
          active: rampActive,
          onTap: () => showRampSheet(context),
        ),
      ],
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? MonoPulseColors.accentOrange
        : MonoPulseColors.textSecondary;
    return Material(
      color: active ? MonoPulseColors.accentOrange10 : MonoPulseColors.surface,
      borderRadius: BorderRadius.circular(MonoPulseRadius.huge),
      child: InkWell(
        borderRadius: BorderRadius.circular(MonoPulseRadius.huge),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: MonoPulseSpacing.lg,
            vertical: MonoPulseSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MonoPulseRadius.huge),
            border: Border.all(
              color: active
                  ? MonoPulseColors.accentOrange
                  : MonoPulseColors.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: MonoPulseSpacing.sm),
              Text(
                label,
                style: MonoPulseTypography.labelMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
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


