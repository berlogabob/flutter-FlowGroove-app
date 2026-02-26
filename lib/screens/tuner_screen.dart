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
        appBar: CustomAppBar.buildSimple(
          context,
          title: 'Tuner',
        ),
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

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MonoPulseColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MonoPulseRadius.xlarge),
        ),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(MonoPulseSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MonoPulseColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: MonoPulseSpacing.lg),
            Text(
              'Tuner Settings',
              style: MonoPulseTypography.headlineMedium.copyWith(
                color: MonoPulseColors.textHighEmphasis,
              ),
            ),
            const SizedBox(height: MonoPulseSpacing.lg),
            _SettingsTile(
              icon: Icons.info_outline,
              title: 'Stage 2 Implementation',
              subtitle: 'Simulated pitch detection. Real detection in Stage 3.',
            ),
            const SizedBox(height: MonoPulseSpacing.sm),
            _SettingsTile(
              icon: Icons.music_note,
              title: 'Frequency Range',
              subtitle: '20 Hz - 2000 Hz',
            ),
            const SizedBox(height: MonoPulseSpacing.sm),
            _SettingsTile(
              icon: Icons.tune,
              title: 'Cents Range',
              subtitle: '±50 cents',
            ),
            const SizedBox(height: MonoPulseSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: MonoPulseColors.surfaceRaised,
            borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
          ),
          child: Icon(icon, color: MonoPulseColors.accentOrange, size: 20),
        ),
        const SizedBox(width: MonoPulseSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: MonoPulseTypography.bodyLarge.copyWith(
                  color: MonoPulseColors.textHighEmphasis,
                  fontWeight: MonoPulseTypography.medium,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: MonoPulseTypography.bodySmall.copyWith(
                  color: MonoPulseColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
