import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../widgets/tools/tool_scaffold.dart';
import '../../widgets/tools/tool_transport_bar.dart';
import '../widgets/metronome/time_signature_block.dart';
import '../widgets/metronome/central_tempo_circle.dart';
import '../widgets/metronome/fine_adjustment_buttons.dart';
import '../widgets/metronome/song_library_block.dart';
import '../../models/metronome_state.dart';
import '../../models/band.dart';
import '../../providers/auth/auth_provider.dart';
import '../../router/app_router.dart';
import 'songs/models/song_form_data.dart';
import '../../widgets/tap_bpm_widget.dart';
import '../../providers/data/data_providers.dart';
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
        showOfflineIndicator: true,
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
        onTap: metronome.toggleHaptics,
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
          onTap: canEditSource
              ? () => _saveMetronomeToSong(context, metronome, state)
              : null,
        ),
      );
    }

    // Save New Song
    items.add(
      PopupMenuItem<void>(
        enabled: canEditSource,
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
        onTap: canEditSource ? () => _navigateToSaveSong(context, state) : null,
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
            .map((row) => List.of(row))
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

class _MetronomePerformanceSurface extends StatelessWidget {
  const _MetronomePerformanceSurface();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final useWideLayout = width >= 720;

    return LayoutBuilder(
      builder: (context, constraints) {
        final content = useWideLayout
            ? const _WidePerformanceLayout()
            : _CompactPerformanceLayout(useScroll: constraints.maxHeight < 640);

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: useWideLayout
                ? MonoPulseSpacing.xxxl
                : MonoPulseSpacing.lg,
            vertical: MonoPulseSpacing.md,
          ),
          child: content,
        );
      },
    );
  }
}

class _CompactPerformanceLayout extends StatelessWidget {
  const _CompactPerformanceLayout({required this.useScroll});

  final bool useScroll;

  @override
  Widget build(BuildContext context) {
    const trailingControls = [
      FineAdjustmentButtons(),
      SizedBox(height: MonoPulseSpacing.md),
      _CountInSelector(),
      SizedBox(height: MonoPulseSpacing.sm),
      _MetronomeTransport(),
      SizedBox(height: MonoPulseSpacing.sm),
      SongLibraryBlock(),
      SizedBox(height: MonoPulseSpacing.sm),
      TapBPMWidget(),
    ];

    if (useScroll) {
      return const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: MonoPulseSpacing.xs),
            TimeSignatureBlock(),
            SizedBox(height: MonoPulseSpacing.md),
            SizedBox(height: 220, child: CentralTempoCircle()),
            SizedBox(height: MonoPulseSpacing.md),
            ...trailingControls,
            SizedBox(height: MonoPulseSpacing.lg),
          ],
        ),
      );
    }

    return const Column(
      children: [
        TimeSignatureBlock(),
        SizedBox(height: MonoPulseSpacing.md),
        Expanded(child: CentralTempoCircle()),
        SizedBox(height: MonoPulseSpacing.sm),
        FineAdjustmentButtons(),
        SizedBox(height: MonoPulseSpacing.md),
        _MetronomeTransport(),
        SizedBox(height: MonoPulseSpacing.sm),
        SongLibraryBlock(),
      ],
    );
  }
}

class _WidePerformanceLayout extends StatelessWidget {
  const _WidePerformanceLayout();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          flex: 3,
          child: Column(
            children: [
              TimeSignatureBlock(),
              SizedBox(height: MonoPulseSpacing.lg),
              Expanded(child: CentralTempoCircle()),
            ],
          ),
        ),
        const SizedBox(width: MonoPulseSpacing.xxxl),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FineAdjustmentButtons(),
              SizedBox(height: MonoPulseSpacing.xl),
              _CountInSelector(),
              SizedBox(height: MonoPulseSpacing.lg),
              _MetronomeTransport(),
              SizedBox(height: MonoPulseSpacing.lg),
              SongLibraryBlock(),
              SizedBox(height: MonoPulseSpacing.lg),
              TapBPMWidget(),
            ],
          ),
        ),
      ],
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

/// Count-in selector widget - allows choosing 0, 1, 2, or 4 count-in bars
class _CountInSelector extends ConsumerWidget {
  const _CountInSelector();

  static const List<int> _options = [0, 1, 2, 4];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countInBars = ref.watch(
      metronomeProvider.select((state) => state.countInBars),
    );
    final metronome = ref.read(metronomeProvider.notifier);
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.timer_outlined,
          color: countInBars > 0
              ? MonoPulseColors.accentOrange
              : MonoPulseColors.textTertiary,
          size: MonoPulseIcons.sizeMedium,
        ),
        const SizedBox(width: MonoPulseSpacing.md),
        Text(
          'Count-in',
          style: MonoPulseTypography.labelLarge.copyWith(
            color: MonoPulseColors.textHighEmphasis,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    final options = Wrap(
      spacing: MonoPulseSpacing.xs,
      runSpacing: MonoPulseSpacing.xs,
      children: _options.map((value) {
        final isSelected = countInBars == value;
        return ChoiceChip(
          label: Text(
            value == 0 ? 'Off' : '$value',
            style: MonoPulseTypography.labelMedium.copyWith(
              color: isSelected
                  ? MonoPulseColors.black
                  : MonoPulseColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          selected: isSelected,
          selectedColor: MonoPulseColors.accentOrange,
          backgroundColor: MonoPulseColors.surfaceRaised,
          side: BorderSide(
            color: isSelected
                ? MonoPulseColors.accentOrange
                : MonoPulseColors.borderSubtle,
          ),
          onSelected: (_) => metronome.setCountInBars(value),
        );
      }).toList(),
    );

    return Material(
      color: MonoPulseColors.surface,
      borderRadius: BorderRadius.circular(MonoPulseRadius.large),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(
          horizontal: MonoPulseSpacing.lg,
          vertical: MonoPulseSpacing.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(MonoPulseRadius.large),
          border: Border.all(color: MonoPulseColors.borderSubtle),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 360) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  label,
                  const SizedBox(height: MonoPulseSpacing.sm),
                  options,
                ],
              );
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [label, options],
            );
          },
        ),
      ),
    );
  }
}
