import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/data/metronome_provider.dart';
import '../../theme/mono_pulse_theme.dart';
import 'central_tempo_circle.dart';

/// Tempo control core: the rotary BPM dial with four step buttons tucked into
/// the corners of its (otherwise empty) bounding box.
///
/// - Bottom corners: −1 / +1 (tap = ±1, press-and-hold = accelerating repeat).
/// - Top corners: −5 / +5 (single tap).
/// - Drag the dial for coarse changes; tap its centre for Enter BPM / Tap Tempo.
class TempoControlCluster extends ConsumerWidget {
  const TempoControlCluster({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(metronomeProvider.notifier);
    return LayoutBuilder(
      builder: (context, constraints) {
        // The dial fills the square; the gauge ring sits inside it, leaving the
        // four corners free, so the step buttons tuck into the corners and hug
        // the ring without enlarging the cluster.
        final dial = math.min(constraints.maxWidth, 300.0);
        return Center(
          child: SizedBox(
            width: dial,
            height: dial,
            child: Stack(
              children: [
                const Positioned.fill(child: CentralTempoCircle()),
                // Top corners: ±5 (coarser, less-frequent → upper reach).
                Positioned(
                  top: 0,
                  left: 0,
                  child: _CornerStepButton(
                    label: '−5',
                    semanticLabel: 'Decrease tempo by 5',
                    onStep: () => notifier.adjustTempoFine(-5),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: _CornerStepButton(
                    label: '+5',
                    semanticLabel: 'Increase tempo by 5',
                    onStep: () => notifier.adjustTempoFine(5),
                  ),
                ),
                // Bottom corners: ±1 (fine, most-used → easy thumb reach),
                // press-and-hold to repeat with acceleration.
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: _CornerStepButton(
                    label: '−1',
                    semanticLabel: 'Decrease tempo by 1',
                    repeat: true,
                    onStep: () => notifier.adjustTempoFine(-1),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: _CornerStepButton(
                    label: '+1',
                    semanticLabel: 'Increase tempo by 1',
                    repeat: true,
                    onStep: () => notifier.adjustTempoFine(1),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A round corner button. Fires [onStep] once on tap; when [repeat] is true it
/// also repeats with accelerating cadence while held.
class _CornerStepButton extends StatefulWidget {
  const _CornerStepButton({
    required this.label,
    required this.semanticLabel,
    required this.onStep,
    this.repeat = false,
  });

  final String label;
  final String semanticLabel;
  final VoidCallback onStep;
  final bool repeat;

  @override
  State<_CornerStepButton> createState() => _CornerStepButtonState();
}

class _CornerStepButtonState extends State<_CornerStepButton> {
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

  void _down() {
    setState(() => _pressed = true);
    _fire();
    if (widget.repeat) {
      _delayMs = _startDelayMs;
      _scheduleNext();
    }
  }

  void _scheduleNext() {
    _timer = Timer(Duration(milliseconds: _delayMs), () {
      _fire();
      _delayMs = (_delayMs - _accelStepMs).clamp(_minDelayMs, _startDelayMs);
      _scheduleNext();
    });
  }

  void _up() {
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
    // Increment and decrement share one neutral style so neither reads as
    // primary/disabled; orange is reserved for the Play transport (UX audit F-009).
    final color = context.mp.textSecondary;
    final background = context.mp.surfaceRaised;

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _down(),
        onTapUp: (_) => _up(),
        onTapCancel: _up,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: MonoPulseAnimation.durationShort,
          curve: MonoPulseAnimation.curveCustom,
          child: Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: background,
              border: Border.all(
                color: context.mp.borderDefault,
                width: 1.5,
              ),
            ),
            child: Text(
              widget.label,
              style: MonoPulseTypography.labelLarge.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
