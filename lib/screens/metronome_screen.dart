import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../models/band.dart';
import '../../models/metronome_preset.dart';
import '../../models/metronome_state.dart';
import '../../models/tempo_ramp.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/data/metronome_provider.dart';
import '../../providers/metronome_preset_provider.dart';
import '../../router/app_router.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../widgets/tap_bpm_widget.dart';
import '../../widgets/tools/tool_scaffold.dart';
import '../../widgets/tools/tool_transport_bar.dart';
import '../widgets/metronome/central_tempo_circle.dart';
import '../widgets/metronome/fine_adjustment_buttons.dart';
import '../widgets/metronome/song_library_block.dart';
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
    } on StateError {
      // The provider may already be disposed with its enclosing ProviderScope.
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
      _PracticeControls(),
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
        _MetronomeContextStatus(),
        SizedBox(height: MonoPulseSpacing.sm),
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
              _MetronomeContextStatus(),
              SizedBox(height: MonoPulseSpacing.sm),
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
              _PracticeControls(),
              SizedBox(height: MonoPulseSpacing.lg),
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

class _MetronomeContextStatus extends ConsumerWidget {
  const _MetronomeContextStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(metronomeProvider);
    final source = state.bpmSource.name
        .replaceAllMapped(RegExp('([A-Z])'), (match) => ' ${match.group(1)}')
        .toUpperCase();
    final title =
        state.activeSong?.title ?? state.activePresetName ?? 'Practice Mode';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MonoPulseTypography.labelLarge.copyWith(
              color: MonoPulseColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: MonoPulseSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: MonoPulseColors.accentOrange.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(MonoPulseRadius.huge),
          ),
          child: Text(
            source,
            style: MonoPulseTypography.labelSmall.copyWith(
              color: MonoPulseColors.accentOrange,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PracticeControls extends ConsumerWidget {
  const _PracticeControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rampActive = ref.watch(
      metronomeProvider.select((state) => state.activeTempoRamp != null),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: MonoPulseSpacing.sm,
      runSpacing: MonoPulseSpacing.xs,
      children: [
        OutlinedButton.icon(
          onPressed: () => _showPresets(context, ref),
          icon: const Icon(Icons.bookmark_outline),
          label: const Text('Presets'),
        ),
        OutlinedButton.icon(
          onPressed: rampActive
              ? ref.read(metronomeProvider.notifier).stopTempoRamp
              : () => _showRamp(context, ref),
          icon: Icon(rampActive ? Icons.stop : Icons.trending_up),
          label: Text(rampActive ? 'Stop Ramp' : 'Tempo Ramp'),
        ),
      ],
    );
  }

  Future<void> _showPresets(BuildContext context, WidgetRef ref) async {
    final presets = await ref.read(metronomePresetProvider.future);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Metronome Presets')),
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await _savePreset(context, ref);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Save Current'),
                ),
              ],
            ),
            const SizedBox(height: MonoPulseSpacing.md),
            if (presets.isEmpty)
              const Padding(
                padding: EdgeInsets.all(MonoPulseSpacing.xl),
                child: Text('No saved presets yet.'),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: presets.length,
                  itemBuilder: (context, index) {
                    final preset = presets[index];
                    return ListTile(
                      title: Text(preset.name),
                      subtitle: Text(preset.displayName),
                      onTap: () {
                        ref
                            .read(metronomeProvider.notifier)
                            .applyPreset(preset);
                        Navigator.pop(sheetContext);
                      },
                      trailing: IconButton(
                        tooltip: 'Delete preset',
                        onPressed: () async {
                          await ref
                              .read(metronomePresetProvider.notifier)
                              .delete(preset.id);
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _savePreset(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save Preset'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Preset name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    final state = ref.read(metronomeProvider);
    final preset = MetronomePreset(
      id: const Uuid().v4(),
      name: name,
      bpm: state.bpm,
      timeSignature: state.timeSignature,
      waveType: state.waveType,
      accentEnabled: state.accentEnabled,
      subdivisions: state.regularBeats,
      beatModes: state.beatModes,
      volume: state.volume,
      countInBars: state.countInBars,
      visualFlashEnabled: state.visualFlashEnabled,
      hapticsEnabled: state.hapticsEnabled,
      createdAt: DateTime.now(),
    );
    await ref.read(metronomePresetProvider.notifier).save(preset);
    ref.read(metronomeProvider.notifier).applyPreset(preset);
  }

  Future<void> _showRamp(BuildContext context, WidgetRef ref) async {
    final current = ref.read(metronomeProvider).bpm;
    final targetController = TextEditingController(text: '${current + 20}');
    final stepController = TextEditingController(text: '2');
    final everyController = TextEditingController(text: '4');
    final ramp = await showDialog<TempoRamp>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tempo Ramp'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: targetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Target BPM'),
            ),
            TextField(
              controller: stepController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Step BPM'),
            ),
            TextField(
              controller: everyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Every N bars'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final target = int.tryParse(targetController.text);
              final step = int.tryParse(stepController.text);
              final every = int.tryParse(everyController.text);
              if (target == null || step == null || every == null) return;
              Navigator.pop(
                dialogContext,
                TempoRamp(
                  id: const Uuid().v4(),
                  name: '$current to $target BPM',
                  startBpm: current,
                  targetBpm: target,
                  stepBpm: step,
                  cadence: TempoRampCadence.bars,
                  every: every,
                ),
              );
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
    targetController.dispose();
    stepController.dispose();
    everyController.dispose();
    if (ramp != null) ref.read(metronomeProvider.notifier).startTempoRamp(ramp);
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
