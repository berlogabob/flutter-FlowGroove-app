import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/tuner_provider.dart';
import '../../theme/mono_pulse_theme.dart';

/// Stage Mode Overlay - Full-screen overlay shown after inactivity.
///
/// After 10 seconds of no interaction, hides all UI elements
/// and shows only a large note name and tuning indicator.
/// Tap anywhere to exit stage mode.
///
/// Usage: Wrap the main tuner content with this widget.
/// The overlay is controlled by [TunerState.stageModeActive].
class StageModeOverlay extends ConsumerStatefulWidget {
  const StageModeOverlay({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  ConsumerState<StageModeOverlay> createState() => _StageModeOverlayState();
}

class _StageModeOverlayState extends ConsumerState<StageModeOverlay> {
  Timer? _inactivityTimer;

  static const _stageModeTimeout = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    // Reset timer when widget is first built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resetInactivityTimer();
    });
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _resetInactivityTimer() {
    final state = ref.read(tunerProvider);
    if (!state.stageModeEnabled) return;

    _inactivityTimer?.cancel();
    // Ensure stage mode is not active when user interacts
    if (state.stageModeActive) {
      ref.read(tunerProvider.notifier).exitStageMode();
    }
    _inactivityTimer = Timer(_stageModeTimeout, () {
      if (mounted) {
        ref.read(tunerProvider.notifier).setStageModeActive(active: true);
      }
    });
  }

  /// Track any interaction to reset the timer.
  void _onInteraction() {
    _resetInactivityTimer();
  }

  void _exitStageMode() {
    HapticFeedback.lightImpact();
    ref.read(tunerProvider.notifier).exitStageMode();
    _resetInactivityTimer();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tunerProvider);

    return GestureDetector(
      // Reset timer on any tap/drag
      onTap: state.stageModeActive ? _exitStageMode : _onInteraction,
      onPanDown: (_) => _onInteraction(),
      child: Stack(
        children: [
          // Main tuner content
          widget.child,

          // Stage mode overlay (shown when active)
          if (state.stageModeActive)
            Positioned.fill(
              child: _StageModeContent(
                onExit: _exitStageMode,
              ),
            ),
        ],
      ),
    );
  }
}

class _StageModeContent extends ConsumerWidget {
  const _StageModeContent({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tunerProvider);

    return GestureDetector(
      onTap: onExit,
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        duration: MonoPulseAnimation.durationLong,
        curve: MonoPulseAnimation.curveDecelerate,
        opacity: 1,
        child: ColoredBox(
          color: MonoPulseColors.black,
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Large note name
                  Text(
                    state.note.split(RegExp(r'\d')).first,
                    style: const TextStyle(
                      fontSize: 120,
                      fontWeight: MonoPulseTypography.bold,
                      color: MonoPulseColors.textHighEmphasis,
                      letterSpacing: -4,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: MonoPulseSpacing.md),
                  // Octave + frequency
                  Text(
                    '${state.note} · ${state.frequency.round()} Hz',
                    style: MonoPulseTypography.headlineMedium.copyWith(
                      color: MonoPulseColors.textTertiary,
                      fontWeight: MonoPulseTypography.medium,
                    ),
                  ),
                  const SizedBox(height: MonoPulseSpacing.xl),
                  // Cents indicator (large)
                  if (state.mode == TunerMode.listen && state.isListening)
                    _LargeCentsIndicator(cents: state.cents),
                  const SizedBox(height: MonoPulseSpacing.massive),
                  // Tuning name indicator
                  if (state.selectedTuning != null)
                    Text(
                      '${state.selectedInstrument?.name ?? ''} · ${state.selectedTuning?.name ?? ''}',
                      style: MonoPulseTypography.bodyLarge.copyWith(
                        color: MonoPulseColors.textTertiary,
                      ),
                    ),
                  const SizedBox(height: MonoPulseSpacing.xxxl),
                  // Tap hint (pulsing)
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.3, end: 1),
                    duration: const Duration(seconds: 2),
                    curve: MonoPulseAnimation.curveCustom,
                    builder: (context, opacity, child) {
                      return AnimatedOpacity(
                        opacity: opacity,
                        duration: const Duration(seconds: 2),
                        child: Text(
                          'Tap to exit Stage Mode',
                          style: MonoPulseTypography.labelSmall.copyWith(
                            color: MonoPulseColors.textDisabled,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Large cents display for stage mode.
class _LargeCentsIndicator extends StatelessWidget {
  const _LargeCentsIndicator({required this.cents});

  final int cents;

  @override
  Widget build(BuildContext context) {
    // Color based on how close to zero
    Color centsColor;
    if (cents == 0) {
      centsColor = MonoPulseColors.accentOrange;
    } else if (cents.abs() <= 5) {
      centsColor = MonoPulseColors.successGreen;
    } else if (cents.abs() <= 15) {
      centsColor = MonoPulseColors.textSecondary;
    } else {
      centsColor = MonoPulseColors.textTertiary;
    }

    final sign = cents > 0 ? '+' : '';
    final displayText = cents == 0 ? '✓ In Tune' : '$sign$cents cents';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: MonoPulseAnimation.curveCustom,
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 48,
          fontWeight: MonoPulseTypography.semibold,
          color: centsColor,
          letterSpacing: -1,
        ),
      ),
    );
  }
}
