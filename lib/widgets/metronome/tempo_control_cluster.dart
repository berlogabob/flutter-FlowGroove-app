import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/data/metronome_provider.dart';
import '../../theme/mono_pulse_theme.dart';
import 'central_tempo_circle.dart';

/// The tempo control core: the rotary BPM dial flanked by large −/+ buttons,
/// with a compact ±5 / ±10 row underneath.
///
/// - Tap −/+ : adjust by 1 BPM.
/// - Press and hold −/+ : repeat with acceleration (slow → fast).
/// - Drag the dial: coarse change. Tap the dial centre: Enter BPM / Tap Tempo.
class TempoControlCluster extends ConsumerWidget {
  const TempoControlCluster({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(metronomeProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const button = 56.0;
            const gap = MonoPulseSpacing.lg;
            final dial = (constraints.maxWidth - button * 2 - gap * 2).clamp(
              160.0,
              300.0,
            );
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _HoldRepeatButton(
                  icon: Icons.remove,
                  semanticLabel: 'Decrease tempo',
                  isAccent: false,
                  onStep: () => notifier.adjustTempoFine(-1),
                ),
                const SizedBox(width: gap),
                SizedBox(
                  width: dial,
                  height: dial,
                  child: const CentralTempoCircle(),
                ),
                const SizedBox(width: gap),
                _HoldRepeatButton(
                  icon: Icons.add,
                  semanticLabel: 'Increase tempo',
                  isAccent: true,
                  onStep: () => notifier.adjustTempoFine(1),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: MonoPulseSpacing.md),
        const _CompactStepRow(),
      ],
    );
  }
}

/// A round button that fires [onStep] once on tap, and repeatedly with
/// accelerating cadence while held.
class _HoldRepeatButton extends StatefulWidget {
  const _HoldRepeatButton({
    required this.icon,
    required this.semanticLabel,
    required this.isAccent,
    required this.onStep,
  });

  final IconData icon;
  final String semanticLabel;
  final bool isAccent;
  final VoidCallback onStep;

  @override
  State<_HoldRepeatButton> createState() => _HoldRepeatButtonState();
}

class _HoldRepeatButtonState extends State<_HoldRepeatButton> {
  static const int _startDelayMs = 380;
  static const int _minDelayMs = 60;
  static const int _accelStepMs = 35;

  Timer? _timer;
  int _delayMs = _startDelayMs;
  bool _pressed = false;

  void _fire() {
    widget.onStep();
    HapticFeedback.selectionClick();
  }

  void _start() {
    setState(() => _pressed = true);
    _fire();
    _delayMs = _startDelayMs;
    _scheduleNext();
  }

  void _scheduleNext() {
    _timer = Timer(Duration(milliseconds: _delayMs), () {
      _fire();
      _delayMs = (_delayMs - _accelStepMs).clamp(_minDelayMs, _startDelayMs);
      _scheduleNext();
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _pressed = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isAccent
        ? MonoPulseColors.accentOrange
        : MonoPulseColors.textSecondary;
    final background = widget.isAccent
        ? MonoPulseColors.accentOrange10
        : MonoPulseColors.surfaceRaised;

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _start(),
        onTapUp: (_) => _stop(),
        onTapCancel: _stop,
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: MonoPulseAnimation.durationShort,
          curve: MonoPulseAnimation.curveCustom,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: background,
              border: Border.all(
                color: widget.isAccent
                    ? MonoPulseColors.accentOrange.withValues(alpha: 0.5)
                    : MonoPulseColors.borderDefault,
                width: 1.5,
              ),
            ),
            child: Icon(widget.icon, color: color, size: 28),
          ),
        ),
      ),
    );
  }
}

/// Compact ±5 / ±10 row kept for users who rely on stepped jumps.
class _CompactStepRow extends ConsumerWidget {
  const _CompactStepRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(metronomeProvider.notifier);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepChip(label: '-10', delta: -10, notifier: notifier),
        const SizedBox(width: MonoPulseSpacing.sm),
        _StepChip(label: '-5', delta: -5, notifier: notifier),
        const SizedBox(width: MonoPulseSpacing.md),
        _StepChip(label: '+5', delta: 5, notifier: notifier, isAccent: true),
        const SizedBox(width: MonoPulseSpacing.sm),
        _StepChip(label: '+10', delta: 10, notifier: notifier, isAccent: true),
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.label,
    required this.delta,
    required this.notifier,
    this.isAccent = false,
  });

  final String label;
  final int delta;
  final MetronomeNotifier notifier;
  final bool isAccent;

  @override
  Widget build(BuildContext context) {
    final color = isAccent
        ? MonoPulseColors.accentOrange
        : MonoPulseColors.textSecondary;
    return Material(
      color: isAccent
          ? MonoPulseColors.accentOrange10
          : MonoPulseColors.surfaceRaised,
      borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
      child: InkWell(
        borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
        onTap: () {
          notifier.adjustTempoFine(delta);
          HapticFeedback.lightImpact();
        },
        child: Container(
          constraints: const BoxConstraints(minWidth: 52, minHeight: 40),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(
            horizontal: MonoPulseSpacing.md,
          ),
          child: Text(
            label,
            style: MonoPulseTypography.labelMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
