import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/tuner_provider.dart';
import '../../theme/mono_pulse_theme.dart';

/// Mode Switcher widget for Tuner screen
///
/// Two horizontal pills for mode selection:
/// - "Generate Tone" and "Listen & Tune"
/// - Height: ~48px
/// - Border radius: 20-24px
/// - Text: 18px Medium
/// - Inactive: background #121212, text #A0A0A5
/// - Active: background #FF5E00, text white
/// - Default active: "Listen & Tune"
///
/// INTERACTIVE: Tap to switch modes with smooth fade animation (200-300ms)
class ModeSwitcher extends ConsumerWidget {
  const ModeSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(tunerModeProvider);
    final notifier = ref.read(tunerProvider.notifier);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Generate Tone pill
        _ModePill(
          label: 'Generate Tone',
          isActive: mode == TunerMode.generate,
          onTap: () {
            HapticFeedback.lightImpact();
            notifier.setMode(TunerMode.generate);
          },
        ),
        const SizedBox(width: MonoPulseSpacing.md),
        // Listen & Tune pill
        _ModePill(
          label: 'Listen & Tune',
          isActive: mode == TunerMode.listen,
          onTap: () {
            HapticFeedback.lightImpact();
            notifier.setMode(TunerMode.listen);
          },
        ),
      ],
    );
  }
}

class _ModePill extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ModePill({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_ModePill> createState() => _ModePillState();
}

class _ModePillState extends State<_ModePill>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: MonoPulseAnimation.curveCustom,
    );

    // Start animation based on initial state
    if (widget.isActive) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_ModePill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          // Interpolate colors based on animation progress
          final bgColor = Color.lerp(
            MonoPulseColors.surface,
            MonoPulseColors.accentOrange,
            _fadeAnimation.value,
          )!;

          final textColor = Color.lerp(
            MonoPulseColors.textSecondary,
            MonoPulseColors.white,
            _fadeAnimation.value,
          )!;

          final borderColor = Color.lerp(
            MonoPulseColors.borderSubtle,
            MonoPulseColors.accentOrange,
            _fadeAnimation.value,
          )!;

          return Container(
            height: 48,
            padding: const EdgeInsets.symmetric(
              horizontal: MonoPulseSpacing.xxl,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(MonoPulseRadius.huge),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Center(
              child: Text(
                widget.label,
                style: MonoPulseTypography.bodyLarge.copyWith(
                  color: textColor,
                  fontWeight: MonoPulseTypography.medium,
                  fontSize: 18,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
