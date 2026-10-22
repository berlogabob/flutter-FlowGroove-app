import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/metronome_state.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/data/drum_active_provider.dart';
import '../../providers/data/metronome_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../router/app_router.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../widgets/app_menu_sheet.dart';
import '../../widgets/tools/tool_scaffold.dart';
import '../../widgets/tools/tool_transport_bar.dart';
import '../models/song_lab.dart';
import '../providers/metronome_runtime_providers.dart';
import '../providers/wakelock_provider.dart';
import '../services/power_reliability.dart';
import '../services/wakelock_controller.dart';
import '../utils/snackbar.dart' show showGlobalSnackBar;
import '../widgets/metronome/backing_sheet.dart';
import '../widgets/metronome/metronome_sheets.dart';
import '../widgets/metronome/reliability_sheet.dart';
import '../widgets/metronome/song_library_block.dart';
import '../widgets/metronome/tempo_control_cluster.dart';
import '../widgets/metronome/time_signature_block.dart';
import '../widgets/practice/launchpad_view.dart';
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
  Timer? _tempoSaveDebounce;
  bool _reliabilityChecked = false;

  @override
  void initState() {
    super.initState();
    _metronome = ref.read(metronomeProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _tempoSaveDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Debounced: writes the current BPM back to the loaded song once the user
  /// settles on a tempo (tap, dial, or typed). Silent on success; the
  /// explicit ⋮ "Save to …" item remains for everything else.
  void _scheduleTempoAutoSave(bool canEditSource) {
    _tempoSaveDebounce?.cancel();
    if (!canEditSource) return;
    _tempoSaveDebounce = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      final state = ref.read(metronomeProvider);
      final song = state.activeSong;
      if (song == null) return;
      if (state.bpm == (song.ourBPM ?? song.originalBPM)) return;
      _saveMetronomeToSong(context, _metronome, state, silent: true);
    });
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
    if (!kIsWeb &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached ||
            state == AppLifecycleState.hidden)) {
      _stopSafely();
    }
  }

  Future<void> _showPowerSetupIfNeeded() async {
    try {
      if (_reliabilityChecked ||
          kIsWeb ||
          defaultTargetPlatform != TargetPlatform.android ||
          ref.read(_activeMidiBackingProvider) == null) {
        return;
      }
      _reliabilityChecked = true;
      final power = PowerReliability();
      if (await power.setupSeen() || !mounted) return;
      await power.markSetupSeen();
      if (!mounted) return;
      await showReliabilitySheet(context, power: power);
    } catch (_) {
      // Optional setup must never interrupt playback on older hosts.
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
        // Canonical band permission (adminUids/editorUids — the same arrays
        // the Firestore rules read), not the ad-hoc members[].role parse
        // that silently defaulted to 'viewer' on docs without roles.
        canEditSource = ref.watch(canEditBandProvider(state.sourceBandId!));
      }
    }

    // Auto-persist a changed tempo to the loaded song (band-aware, debounced)
    // — a tapped or typed tempo used to evaporate unless the user found the
    // ⋮ "Save to …" item.
    ref.listen(metronomeProvider.select((s) => s.bpm), (prev, next) {
      _scheduleTempoAutoSave(canEditSource);
    });

    ref.listen(metronomeProvider.select((s) => s.isPlaying), (prev, next) {
      if (prev != true && next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_showPowerSetupIfNeeded());
        });
      }
    });

    return ScreenWakelock(
      controller: ref.watch(wakelockProvider),
      isPlaying: state.isPlaying,
      onWebResume: () => ref
          .read(metronomePlaybackClientProvider)
          .resetPhase(
            MetronomePlaybackConfig.fromState(ref.read(metronomeProvider)),
          ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
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
      ),
    );
  }

  /// Builds items for the bottom-bar Menu sheet.
  ///
  /// Sound / Count-in / Ramp live here instead of on the main screen, so the
  /// metronome stays clean (Mono Pulse: "main window stays clean"). Their
  /// current values are folded into the row labels; Haptics is a live toggle
  /// (`trailing` switch rebuilds in-sheet via Riverpod and does not close the
  /// sheet, so several settings can be flipped in one visit).
  List<AppMenuItem> _buildMenuItems(
    BuildContext context,
    MetronomeNotifier metronome,
    MetronomeState state, {
    required bool canEditSource,
  }) {
    return [
      // Concert Mode — full-screen stage view (Mono Pulse).
      AppMenuItem(
        icon: Icons.theaters_outlined,
        label: 'Concert Mode',
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => const ConcertModeScreen(),
            fullscreenDialog: true,
          ),
        ),
      ),
      AppMenuItem(
        icon: Icons.graphic_eq,
        label: 'Sound: Click',
        onTap: () => showSoundSheet(context),
      ),
      AppMenuItem(
        icon: Icons.timer_outlined,
        label: state.countInBars > 0
            ? 'Count-in: ${state.countInBars} bars'
            : 'Count-in: Off',
        onTap: () => showCountInSheet(context),
      ),
      AppMenuItem(
        icon: Icons.trending_up,
        label: state.activeTempoRamp != null ? 'Ramp: On' : 'Ramp: Off',
        onTap: () => showRampSheet(context),
      ),
      AppMenuItem(
        icon: state.hapticsEnabled ? Icons.vibration : Icons.mobile_off,
        label: 'Haptics',
        onTap: metronome.toggleHaptics,
        trailing: Consumer(
          builder: (context, ref, _) {
            final enabled = ref.watch(
              metronomeProvider.select((s) => s.hapticsEnabled),
            );
            return Switch(
              value: enabled,
              activeThumbColor: MonoPulseColors.accentOrange,
              onChanged: (_) =>
                  ref.read(metronomeProvider.notifier).toggleHaptics(),
            );
          },
        ),
      ),
      // Save to Song (only shown when song is loaded). When the user lacks
      // the band role, tapping explains why instead of a silent grey row.
      if (state.activeSong != null) ...[
        AppMenuItem(
          icon: Icons.edit_outlined,
          label: 'Edit Song',
          onTap: canEditSource
              ? () => _navigateToEditSong(context, state)
              : () => _showErrorSnackBar(
                  context,
                  'Only band editors can change this song',
                ),
        ),
        AppMenuItem(
          icon: Icons.save_outlined,
          label: "Save to '${state.activeSong!.title}'",
          onTap: canEditSource
              ? () => _saveMetronomeToSong(context, metronome, state)
              : () => _showErrorSnackBar(
                  context,
                  'Only band editors can save to this song',
                ),
        ),
      ],
      AppMenuItem(
        icon: Icons.add_circle_outline,
        label: 'Save New Song',
        onTap: canEditSource ? () => _navigateToSaveSong(context, state) : null,
      ),
    ];
  }

  /// Save current metronome settings to the loaded song. [silent] is the
  /// debounced auto-save path: no success toast, errors still surface.
  Future<void> _saveMetronomeToSong(
    BuildContext context,
    MetronomeNotifier metronome,
    MetronomeState state, {
    bool silent = false,
  }) async {
    final updatedSong = metronome.saveMetronomeToSong();
    if (updatedSong == null) {
      if (!silent) _showErrorSnackBar(context, 'No song loaded');
      return;
    }

    try {
      // Get current user
      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user == null) {
        if (!silent) _showErrorSnackBar(context, 'Not signed in');
        return;
      }

      final repository = ref.read(songRepositoryProvider);
      if (state.sourceBandId != null) {
        await repository.updateBandSong(updatedSong, state.sourceBandId!);
      } else {
        await repository.updateSong(updatedSong, uid: user.uid);
      }

      if (!context.mounted || silent) return;
      _showSuccessSnackBar(
        context,
        "Saved metronome settings to '${updatedSong.title}'",
      );
    } catch (e) {
      if (!context.mounted) {
        // The debounced auto-save regularly fires after navigating away —
        // the root messenger keeps the failure visible instead of dropping it.
        showGlobalSnackBar(
          'Failed to save metronome settings: $e',
          error: true,
        );
        return;
      }
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
        beatModes: state.beatModes.map(List.of).toList(growable: false),
      ),
    );
  }

  void _navigateToEditSong(BuildContext context, MetronomeState state) {
    final song = state.activeSong;
    if (song == null) return;

    context.pushNamed(
      'song',
      pathParameters: {'id': song.id},
      queryParameters: {
        'tab': 'edit',
        if (state.sourceBandId case final b?) 'bandId': b,
      },
      extra: state.sourceBandId == null
          ? song
          : {'song': song, 'bandId': state.sourceBandId},
    );
  }
}

final _activeMidiBackingProvider = Provider<SongLabEntry?>((ref) {
  if (kIsWeb || defaultTargetPlatform == TargetPlatform.iOS) return null;
  final state = ref.watch(metronomeProvider);
  final song = state.activeSong;
  if (song == null || ref.watch(authStateProvider).value == null) return null;
  final entries = ref
      .watch(labEntriesProvider((song.id, state.sourceBandId)))
      .value;
  for (final entry in entries ?? <SongLabEntry>[]) {
    if (entry.type == LabEntryType.midi && entry.midiSong?.fileUrl != null) {
      return entry;
    }
  }
  return null;
});

/// Adaptive metronome layout (Mono Pulse audit A6).
///
/// Portrait: a centered, max-width, scrollable column — phone fills the width,
/// web/tablet centers with gutters. Landscape: the dial moves to the left and
/// the beat map / transport / tools / library stack on the right, so the dial
/// no longer clips under the app bar on short heights.
class _MetronomePerformanceSurface extends ConsumerWidget {
  const _MetronomePerformanceSurface();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(_activeMidiBackingProvider) != null) {
      return const _MetronomeSongLibrary();
    }
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
    final horizontalPadding = MediaQuery.sizeOf(context).width < 375
        ? MonoPulseSpacing.md
        : MonoPulseSpacing.lg;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            MonoPulseSpacing.sm,
            horizontalPadding,
            MonoPulseSpacing.md,
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TimeSignatureBlock(),
              SizedBox(height: MonoPulseSpacing.sm),
              TempoControlCluster(),
              SizedBox(height: MonoPulseSpacing.md),
              _MetronomeTransport(),
              SizedBox(height: MonoPulseSpacing.md),
              _MetronomeSongLibrary(),
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
                  _MetronomeSongLibrary(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetronomeSongLibrary extends ConsumerWidget {
  const _MetronomeSongLibrary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(metronomeProvider);
    final active = ref.watch(drumActiveProvider);

    final onPressed = state.activeSong == null
        ? null
        : () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => BackingSheet(
              songId: state.activeSong!.id,
              bandId: state.sourceBandId,
            ),
          );

    // ponytail: drums are native-only until the web drum player has run in a
    // real browser (it compiles, but was never exercised). Remove this guard
    // after a manual web test.
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.iOS) {
      return const SongLibraryBlock();
    }

    final entry = ref.watch(_activeMidiBackingProvider);
    if (entry != null) {
      return LaunchpadView(
        key: ValueKey(entry.id),
        entry: entry,
        sections: state.activeSong!.sections,
        header: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TimeSignatureBlock(),
            SizedBox(height: MonoPulseSpacing.sm),
            TempoControlCluster(),
            SizedBox(height: MonoPulseSpacing.md),
            SongLibraryBlock(),
            SizedBox(height: MonoPulseSpacing.md),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SongLibraryBlock(),
        const SizedBox(height: MonoPulseSpacing.sm),
        Tooltip(
          message: 'Backing tracks',
          child: active == null
              ? OutlinedButton.icon(
                  icon: const Icon(Icons.album_outlined),
                  label: const Text('Backing tracks'),
                  onPressed: onPressed,
                )
              : FilledButton.icon(
                  icon: const Icon(Icons.album_outlined),
                  label: Text('Drums · $active'),
                  onPressed: onPressed,
                ),
        ),
        if (state.activeSong == null)
          Text(
            'Pick a song first',
            style: Theme.of(context).textTheme.bodySmall,
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
