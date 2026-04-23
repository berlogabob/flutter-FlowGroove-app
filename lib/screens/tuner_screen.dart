import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/tuner_provider.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../widgets/tools/tool_mode_switcher.dart';
import '../../widgets/tools/tool_scaffold.dart';
import '../widgets/tuner/central_dial.dart';
import '../widgets/tuner/custom_tuning_editor.dart';
import '../widgets/tuner/detection_mode_toggle.dart';
import '../widgets/tuner/instrument_picker.dart';
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
  const TunerScreen({super.key});

  @override
  ConsumerState<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends ConsumerState<TunerScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tunerProvider);

    return ToolScreenScaffold(
      title: 'Tuner',
      menuItems: _buildMenuItems(state),
      mainWidget: StageModeOverlay(
        child: _buildMainContent(state),
      ),
      bottomWidget: const TransportBar(),
    );
  }

  List<PopupMenuEntry<dynamic>> _buildMenuItems(TunerState state) {
    return [
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
      builder: (context) => const CustomTuningEditor(),
    );
  }

  Widget _buildMainContent(TunerState state) {
    final notifier = ref.read(tunerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.xxxl),
      child: Column(
        children: [
          const SizedBox(height: MonoPulseSpacing.huge),

          // Mode Switcher
          ToolModeSwitcher<TunerMode>(
            activeMode: state.mode,
            options: const [
              ToolModeOption(
                mode: TunerMode.generate,
                label: 'Generate Tone',
                icon: Icons.graphic_eq,
              ),
              ToolModeOption(
                mode: TunerMode.listen,
                label: 'Listen & Tune',
                icon: Icons.mic,
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

          // Detection mode toggle (only in Listen mode)
          if (state.mode == TunerMode.listen) ...[
            const SizedBox(height: MonoPulseSpacing.lg),
            const DetectionModeToggle(),
          ],

          // Central dial
          const SizedBox(height: MonoPulseSpacing.massive),
          const Expanded(child: CentralDial()),
        ],
      ),
    );
  }
}
