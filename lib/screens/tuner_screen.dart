import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tuner_launch_context.dart';
import '../models/tuner_preset.dart';
import '../providers/tuner_provider.dart';
import '../services/analytics_service.dart';
import '../theme/mono_pulse_theme.dart';
import '../widgets/tools/tool_mode_switcher.dart';
import '../widgets/tools/tool_scaffold.dart';
import '../widgets/tuner/central_dial.dart';
import '../widgets/tuner/custom_tuning_editor.dart';
import '../widgets/tuner/detection_mode_toggle.dart';
import '../widgets/tuner/instrument_picker.dart';
import '../widgets/tuner/stage_mode_overlay.dart';
import '../widgets/tuner/settings_sheet.dart';
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
  final TunerLaunchContext? launchContext;

  const TunerScreen({super.key, this.launchContext});

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

  List<PopupMenuEntry<dynamic>> _buildMenuItems(TunerState state) {
    return [
      PopupMenuItem<dynamic>(
        onTap: _showSettings,
        child: Row(
          children: [
            const Icon(
              Icons.tune,
              color: MonoPulseColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: MonoPulseSpacing.md),
            Text(
              'Tuner Settings',
              style: MonoPulseTypography.bodyMedium.copyWith(
                color: MonoPulseColors.textHighEmphasis,
              ),
            ),
          ],
        ),
      ),
      PopupMenuItem<dynamic>(
        onTap: _showInstrumentPicker,
        child: Row(
          children: [
            const Icon(
              Icons.piano_outlined,
              color: MonoPulseColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: MonoPulseSpacing.md),
            Text(
              'Instruments & Tunings',
              style: MonoPulseTypography.bodyMedium.copyWith(
                color: MonoPulseColors.textHighEmphasis,
              ),
            ),
          ],
        ),
      ),
      PopupMenuItem<dynamic>(
        onTap: _showCustomTuningEditor,
        child: Row(
          children: [
            const Icon(
              Icons.edit_outlined,
              color: MonoPulseColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: MonoPulseSpacing.md),
            Text(
              'Custom Tuning Editor',
              style: MonoPulseTypography.bodyMedium.copyWith(
                color: MonoPulseColors.textHighEmphasis,
              ),
            ),
          ],
        ),
      ),
      PopupMenuItem<dynamic>(
        onTap: () => ref.read(tunerProvider.notifier).toggleStageModeEnabled(),
        child: Row(
          children: [
            Icon(
              state.stageModeEnabled
                  ? Icons.fullscreen
                  : Icons.fullscreen_outlined,
              color: MonoPulseColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: MonoPulseSpacing.md),
            Text(
              'Stage Mode',
              style: MonoPulseTypography.bodyMedium.copyWith(
                color: MonoPulseColors.textHighEmphasis,
              ),
            ),
            const Spacer(),
            Container(
              width: 40,
              height: 24,
              decoration: BoxDecoration(
                color: state.stageModeEnabled
                    ? MonoPulseColors.accentOrange
                    : MonoPulseColors.borderDefault,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  AnimatedAlign(
                    duration: MonoPulseAnimation.durationMedium,
                    curve: MonoPulseAnimation.curveCustom,
                    alignment: state.stageModeEnabled
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: const Padding(
                      padding: EdgeInsets.all(3),
                      child: ColoredBox(
                        color: MonoPulseColors.white,
                        child: SizedBox(width: 18, height: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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

          // Instrument/tuning indicator (compact)
          if (state.selectedInstrument != null) ...[
            const SizedBox(height: MonoPulseSpacing.lg),
            GestureDetector(
              onTap: _showInstrumentPicker,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MonoPulseSpacing.lg,
                  vertical: MonoPulseSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: MonoPulseColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
                  border: Border.all(color: MonoPulseColors.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.piano_outlined,
                      color: MonoPulseColors.accentOrange,
                      size: 16,
                    ),
                    const SizedBox(width: MonoPulseSpacing.sm),
                    Text(
                      state.selectedInstrument!.name,
                      style: MonoPulseTypography.labelMedium.copyWith(
                        color: MonoPulseColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: MonoPulseSpacing.xs),
                    Text(
                      '·',
                      style: MonoPulseTypography.labelMedium.copyWith(
                        color: MonoPulseColors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: MonoPulseSpacing.xs),
                    Text(
                      state.selectedTuning?.name ?? '',
                      style: MonoPulseTypography.labelMedium.copyWith(
                        color: MonoPulseColors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: MonoPulseSpacing.sm),
                    const Icon(
                      Icons.chevron_right,
                      color: MonoPulseColors.textTertiary,
                      size: 16,
                    ),
                  ],
                ),
              ),
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
            if (state.permissionState.name == 'notRequested') ...[
              const SizedBox(height: MonoPulseSpacing.md),
              _InfoCard(
                icon: Icons.privacy_tip_outlined,
                text:
                    'Your microphone is used only on this device for pitch detection. Audio is never stored or uploaded.',
              ),
            ],
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
              'A4 ${state.referenceA4.round()} Hz · Tolerance ±${state.centsTolerance} cents',
              style: MonoPulseTypography.labelSmall.copyWith(
                color: MonoPulseColors.textTertiary,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Save this custom preset to your account before linking it.',
          ),
        ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tuning preset linked.')));
    }
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MonoPulseSpacing.md),
      decoration: BoxDecoration(
        color: MonoPulseColors.surfaceRaised,
        borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
        border: Border.all(color: MonoPulseColors.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(icon, color: MonoPulseColors.accentOrange, size: 18),
          const SizedBox(width: MonoPulseSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: MonoPulseTypography.bodySmall.copyWith(
                color: MonoPulseColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final bool showSettings;
  final VoidCallback onSettings;

  const _ErrorCard({
    required this.message,
    required this.showSettings,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MonoPulseSpacing.md),
      decoration: BoxDecoration(
        color: MonoPulseColors.surfaceRaised,
        borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
        border: Border.all(color: MonoPulseColors.borderSubtle),
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
                color: MonoPulseColors.textSecondary,
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
  final String note;
  final int octave;
  final List<String> notes;
  final bool droneEnabled;
  final void Function(String note, int octave) onNoteChanged;
  final VoidCallback onDroneChanged;

  const _ToneControls({
    required this.note,
    required this.octave,
    required this.notes,
    required this.droneEnabled,
    required this.onNoteChanged,
    required this.onDroneChanged,
  });

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
          dropdownColor: MonoPulseColors.surfaceRaised,
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
          dropdownColor: MonoPulseColors.surfaceRaised,
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
  final String songTitle;
  final bool isSetlistItem;
  final bool canSave;
  final VoidCallback onLink;

  const _SongContextCard({
    required this.songTitle,
    required this.isSetlistItem,
    required this.canSave,
    required this.onLink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MonoPulseSpacing.md,
        vertical: MonoPulseSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: MonoPulseColors.surfaceRaised,
        borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
        border: Border.all(color: MonoPulseColors.borderSubtle),
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
                color: MonoPulseColors.textSecondary,
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
