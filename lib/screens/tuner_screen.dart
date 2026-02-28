import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../providers/tuner_provider.dart';
import '../../widgets/tools/tool_scaffold.dart';
import '../../widgets/tools/tool_mode_switcher.dart';
import '../widgets/tuner/central_dial.dart';
import '../widgets/tuner/transport_bar.dart';

/// Tuner Screen - Mono Pulse Design (Stage 2 - Fully Interactive)
///
/// Complete interactive implementation per Mono Pulse brandbook:
/// - Premium minimalism - expensive prototype feel
/// - True black background + orange accent ONLY
/// - Maximum air (60-70% empty space)
/// - Clean, confident, stage-ready
///
/// STAGE 2 FEATURES:
/// - Mode switching with smooth fade animation (200-300ms)
/// - Generate Tone: drag to change frequency, play/stop sine wave
/// - Listen & Tune: simulated pitch detection, needle indicator
/// - Audio playback with envelope (no clicks)
/// - Microphone permission handling
///
/// Screen Structure (Top to Bottom):
/// 1. AppBar (~56px) - Back arrow, "Tuner" title, three dots
/// 2. Mode Switcher (~48px) - Two pills: "Generate Tone" / "Listen & Tune"
/// 3. Central Circle (50-60% screen width) - Frequency display with tick marks
/// 4. Bottom Transport Bar (64-80px) - Play button + icons
class TunerScreen extends ConsumerStatefulWidget {
  const TunerScreen({super.key});

  @override
  ConsumerState<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends ConsumerState<TunerScreen> {
  @override
  void dispose() {
    // Clean up tuner resources
    ref.read(tunerProvider.notifier).dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tunerProvider);
    final notifier = ref.read(tunerProvider.notifier);

    return ToolScreenScaffold(
      title: 'Tuner',
      mainWidget: _buildMainContent(notifier, state),
      bottomWidget: const TransportBar(),
    );
  }

  Widget _buildMainContent(TunerNotifier notifier, TunerState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.xxxl),
      child: Column(
        children: [
          const SizedBox(height: MonoPulseSpacing.huge),
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
            onModeChanged: (mode) => notifier.setMode(mode),
          ),
          const SizedBox(height: MonoPulseSpacing.massive),
          const Expanded(child: CentralDial()),
        ],
      ),
    );
  }
}
