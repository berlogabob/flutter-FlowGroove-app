import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tuner_launch_context.dart';
import '../models/tuner_preset.dart';
import '../providers/tuner_provider.dart';
import '../services/analytics_service.dart';
import '../theme/mono_pulse_theme.dart';
import '../utils/snackbar.dart';
import '../widgets/app_menu_sheet.dart';
import '../widgets/tools/tool_mode_switcher.dart';
import '../widgets/tools/tool_scaffold.dart';
import '../widgets/tuner/central_dial.dart';
import '../widgets/tuner/custom_tuning_editor.dart';
import '../widgets/tuner/detection_mode_toggle.dart';
import '../widgets/tuner/instrument_picker.dart';
import '../widgets/tuner/settings_sheet.dart';
import '../widgets/tuner/stage_mode_overlay.dart';
import '../widgets/tuner/transport_bar.dart';

/// Tuner Screen - Mono Pulse Design (Post-MVP)
///
/// Complete implementation with all Post-MVP features:
/// - Regional Instruments (Guitar, Cavaquinho, Balalaika, Ukulele, Sitar)
/// - Auto/Manual Note Detection
/// - Custom Tuning Editor
/// - Stage Mode (auto-hide UI after inactivity)
///
/// Screen Structure (Top to Bottom):
/// 1. AppBar (~56px) - Back arrow, "Tuner" title, instrument picker, three dots
/// 2. Mode Switcher (~48px) - Two pills: "Generate Tone" / "Listen & Tune"
/// 3. [Listen mode only] Detection Mode Toggle (Auto/Manual)
/// 4. [Listen mode + Manual] String Selector row
/// 5. Central Circle (50-60% screen width) - Frequency display with tick marks
/// 6. Bottom Transport Bar (64-80px) - Play button + icons
class TunerScreen extends ConsumerStatefulWidget {
  const TunerScreen({super.key, this.launchContext});

  final TunerLaunchContext? launchContext;

  @override
  ConsumerState<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends ConsumerState<TunerScreen>
    with WidgetsBindingObserver {
  static const _toneNotes = <String>[
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AnalyticsService.logTunerEvent('tuner_opened');
    final presetId = widget.launchContext?.initialPresetId;
    final launchContext = widget.launchContext;
    if (launchContext != null) {
      Future.microtask(
        () => ref
            .read(tunerProvider.notifier)
            .loadContextPresets(
              bandId: launchContext.effectiveBandId,
              songId: launchContext.song.id,
            ),
      );
    }
    if (presetId != null) {
      Future.microtask(
        () => ref.read(tunerProvider.notifier).selectPresetById(presetId),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(tunerProvider.notifier).stopAll();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(tunerProvider.notifier).stopAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tunerProvider);

    return ToolScreenScaffold(
      title: 'Tuner',
      menuItems: _buildMenuItems(state),
      mainWidget: StageModeOverlay(child: _buildMainContent(state)),
      bottomWidget: const TransportBar(),
    );
  }

  List<AppMenuItem> _buildMenuItems(TunerState state) {
    return [
      AppMenuItem(
        icon: Icons.tune,
        label: 'Tuner Settings',
        onTap: _showSettings,
      ),
      AppMenuItem(
        icon: Icons.piano_outlined,
        label: 'Instruments & Tunings',
        onTap: _showInstrumentPicker,
      ),
      AppMenuItem(
        icon: Icons.edit_outlined,
        label: 'Custom Tuning Editor',
        onTap: _showCustomTuningEditor,
      ),
      // Live toggle: the trailing switch rebuilds in-sheet via Riverpod and
      // does not close the sheet.
      AppMenuItem(
        icon: state.stageModeEnabled
            ? Icons.fullscreen
            : Icons.fullscreen_outlined,
        label: 'Stage Mode',
        onTap: () => ref.read(tunerProvider.notifier).toggleStageModeEnabled(),
        trailing: Consumer(
          builder: (context, ref, _) {
            final enabled = ref.watch(
              tunerProvider.select((s) => s.stageModeEnabled),
            );
            return Switch(
              value: enabled,
              activeThumbColor: MonoPulseColors.accentOrange,
              onChanged: (_) =>
                  ref.read(tunerProvider.notifier).toggleStageModeEnabled(),
            );
          },
        ),
      ),
    ];
  }

  void _showInstrumentPicker() {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const InstrumentPicker(),
    );
  }

  void _showCustomTuningEditor() {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CustomTuningEditor(
        bandId: widget.launchContext?.effectiveBandId,
        songId: widget.launchContext?.song.id,
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const TunerSettingsSheet(),
    );
  }

  Widget _buildMainContent(TunerState state) {
    final notifier = ref.read(tunerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.xxxl),
      child: Column(
        children: [
          const SizedBox(height: MonoPulseSpacing.xl),

          // Mode Switcher
          ToolModeSwitcher<TunerMode>(
            activeMode: state.mode,
            options: const [
              ToolModeOption(
                mode: TunerMode.listen,
                label: 'Listen',
                icon: Icons.mic,
              ),
              ToolModeOption(
                mode: TunerMode.generate,
                label: 'Tone',
                icon: Icons.graphic_eq,
              ),
            ],
            onModeChanged: notifier.setMode,
          ),

          // Instrument/tuning indicator (full-width card)
          if (state.selectedInstrument != null) ...[
            const SizedBox(height: MonoPulseSpacing.lg),
            _InstrumentCard(
              instrumentName: state.selectedInstrument!.name,
              tuningName: state.selectedTuning?.name ?? '',
              onTap: _showInstrumentPicker,
            ),
          ],

          if (widget.launchContext != null) ...[
            const SizedBox(height: MonoPulseSpacing.md),
            _SongContextCard(
              songTitle: widget.launchContext!.song.title,
              isSetlistItem: widget.launchContext!.setlistItemId != null,
              canSave: widget.launchContext!.setlistItemId != null
                  ? widget.launchContext!.saveSetlist != null
                  : widget.launchContext!.saveSong != null,
              onLink: _linkCurrentPreset,
            ),
          ],

          // Detection mode toggle (only in Listen mode)
          if (state.mode == TunerMode.listen) ...[
            const SizedBox(height: MonoPulseSpacing.lg),
            const DetectionModeToggle(),
            // Mic-privacy copy lives in Settings only (Mono Pulse: "main window
            // stays clean") — it was duplicated here.
            if (state.errorMessage != null) ...[
              const SizedBox(height: MonoPulseSpacing.md),
              _ErrorCard(
                message: state.errorMessage!,
                showSettings: state.permissionState.name == 'permanentlyDenied',
                onSettings: notifier.openPermissionSettings,
              ),
            ],
          ] else ...[
            const SizedBox(height: MonoPulseSpacing.lg),
            _ToneControls(
              note: state.note.replaceAll(RegExp(r'-?\d+$'), ''),
              octave:
                  int.tryParse(
                    RegExp(r'-?\d+$').firstMatch(state.note)?.group(0) ?? '4',
                  ) ??
                  4,
              notes: _toneNotes,
              droneEnabled: state.droneEnabled,
              onNoteChanged: notifier.setToneNote,
              onDroneChanged: notifier.toggleDrone,
            ),
          ],

          // Central dial
          const SizedBox(height: MonoPulseSpacing.xl),
          const Expanded(child: CentralDial()),
          Padding(
            padding: const EdgeInsets.only(bottom: MonoPulseSpacing.sm),
            child: Text(
              'A4 ${state.referenceA4.round()} Hz · ±${state.centsTolerance} cents',
              style: MonoPulseTypography.labelSmall.copyWith(
                color: context.mp.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _linkCurrentPreset() async {
    final contextData = widget.launchContext;
    final presetId = ref.read(tunerProvider).selectedPresetId;
    final presetScope = ref.read(tunerProvider).selectedPresetScope;
    if (contextData == null || presetId == null) return;
    if (presetScope == TunerPresetScope.local) {
      showAppSnackBar(
        context,
        'Save this custom preset to your account before linking it.',
      );
      return;
    }

    final itemId = contextData.setlistItemId;
    if (itemId != null &&
        contextData.setlist != null &&
        contextData.saveSetlist != null) {
      await contextData.saveSetlist!(
        contextData.setlist!.withItemTuningPreset(itemId, presetId),
      );
    } else if (contextData.saveSong != null) {
      await contextData.saveSong!(
        contextData.song.copyWith(defaultTuningPresetId: presetId),
      );
    } else {
      return;
    }
    await AnalyticsService.logTunerEvent('tuner_song_preset_linked', {
      'target': itemId == null ? 'song' : 'setlist_item',
    });
    if (mounted) {
      showAppSnackBar(context, 'Tuning preset linked.');
    }
  }
}

class _InstrumentCard extends StatelessWidget {
  const _InstrumentCard({
    required this.instrumentName,
    required this.tuningName,
    required this.onTap,
  });

  final String instrumentName;
  final String tuningName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: MonoPulseSpacing.md,
          vertical: MonoPulseSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: context.mp.surfaceRaised,
          borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
          border: Border.all(color: context.mp.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: MonoPulseColors.accentOrange.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(MonoPulseRadius.small),
              ),
              child: const Icon(
                Icons.piano_outlined,
                color: MonoPulseColors.accentOrange,
                size: 20,
              ),
            ),
            const SizedBox(width: MonoPulseSpacing.md),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: instrumentName,
                      style: MonoPulseTypography.titleMedium.copyWith(
                        color: context.mp.textHighEmphasis,
                      ),
                    ),
                    if (tuningName.isNotEmpty)
                      TextSpan(
                        text: '  ·  $tuningName',
                        style: MonoPulseTypography.bodyMedium.copyWith(
                          color: context.mp.textTertiary,
                        ),
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: MonoPulseSpacing.sm),
            Icon(Icons.chevron_right, color: context.mp.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.showSettings,
    required this.onSettings,
  });

  final String message;
  final bool showSettings;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MonoPulseSpacing.md),
      decoration: BoxDecoration(
        color: context.mp.surfaceRaised,
        borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
        border: Border.all(color: context.mp.borderSubtle),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: MonoPulseColors.accentOrange,
            size: 18,
          ),
          const SizedBox(width: MonoPulseSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: MonoPulseTypography.bodySmall.copyWith(
                color: context.mp.textSecondary,
              ),
            ),
          ),
          if (showSettings)
            TextButton(onPressed: onSettings, child: const Text('Settings')),
        ],
      ),
    );
  }
}

class _ToneControls extends StatelessWidget {
  const _ToneControls({
    required this.note,
    required this.octave,
    required this.notes,
    required this.droneEnabled,
    required this.onNoteChanged,
    required this.onDroneChanged,
  });

  final String note;
  final int octave;
  final List<String> notes;
  final bool droneEnabled;
  final void Function(String note, int octave) onNoteChanged;
  final VoidCallback onDroneChanged;

  @override
  Widget build(BuildContext context) {
    final safeNote = notes.contains(note) ? note : 'A';
    final safeOctave = octave.clamp(0, 8);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: MonoPulseSpacing.lg,
      children: [
        DropdownButton<String>(
          value: safeNote,
          dropdownColor: context.mp.surfaceRaised,
          items: notes
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) onNoteChanged(value, safeOctave);
          },
        ),
        DropdownButton<int>(
          value: safeOctave,
          dropdownColor: context.mp.surfaceRaised,
          items: List.generate(
            9,
            (value) =>
                DropdownMenuItem(value: value, child: Text('Octave $value')),
          ),
          onChanged: (value) {
            if (value != null) onNoteChanged(safeNote, value);
          },
        ),
        FilterChip(
          selected: droneEnabled,
          label: const Text('Drone'),
          avatar: const Icon(Icons.waves, size: 18),
          onSelected: (_) => onDroneChanged(),
        ),
      ],
    );
  }
}

class _SongContextCard extends StatelessWidget {
  const _SongContextCard({
    required this.songTitle,
    required this.isSetlistItem,
    required this.canSave,
    required this.onLink,
  });

  final String songTitle;
  final bool isSetlistItem;
  final bool canSave;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MonoPulseSpacing.md,
        vertical: MonoPulseSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.mp.surfaceRaised,
        borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
        border: Border.all(color: context.mp.borderSubtle),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.library_music_outlined,
            color: MonoPulseColors.accentOrange,
            size: 18,
          ),
          const SizedBox(width: MonoPulseSpacing.sm),
          Expanded(
            child: Text(
              songTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MonoPulseTypography.labelMedium.copyWith(
                color: context.mp.textSecondary,
              ),
            ),
          ),
          if (canSave)
            TextButton(
              onPressed: onLink,
              child: Text(isSetlistItem ? 'Use for item' : 'Use for song'),
            ),
        ],
      ),
    );
  }
}
