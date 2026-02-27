import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../providers/tuner_provider.dart';
import '../widgets/tuner/mode_switcher.dart';
import '../widgets/tuner/central_dial.dart';
import '../widgets/tuner/transport_bar.dart';
import '../widgets/custom_app_bar.dart';

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: MonoPulseColors.black,
        appBar: CustomAppBar.buildSimple(context, title: 'Tuner'),
        body: SafeArea(child: _buildBody(context)),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.xxxl),
      child: Column(
        children: [
          // 1. Air gap after AppBar (64-80px)
          const SizedBox(height: MonoPulseSpacing.huge),

          // 2. Mode Switcher (Two pills) with AnimatedSwitcher
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: MonoPulseAnimation.curveCustom,
            switchOutCurve: MonoPulseAnimation.curveCustom,
            child: const ModeSwitcher(),
          ),

          // Air gap to circle (48px)
          const SizedBox(height: MonoPulseSpacing.massive),

          // 3. Central Circle (Main Visual)
          const Expanded(child: CentralDial()),

          // Air gap to transport bar (48-64px)
          const SizedBox(height: MonoPulseSpacing.massive),

          // 4. Bottom Transport Bar
          const TransportBar(),

          // Bottom padding for SafeArea
          const SizedBox(height: MonoPulseSpacing.lg),
        ],
      ),
    );
  }
}
