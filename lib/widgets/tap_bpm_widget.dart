import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/data/metronome_provider.dart';
import '../theme/mono_pulse_theme.dart';

/// Tap BPM widget - calculate tempo by tapping
///
/// Mono Pulse Design (Sprint Fix):
/// - Circle: #121212 background, #222222 stroke
/// - Icon: #A0A0A5 (secondary text color)
/// - Active state: #FF5E00 accent
/// - Minimum 48px touch zone
/// - Animations: 120ms, curveCustom
class TapBPMWidget extends ConsumerStatefulWidget {
  const TapBPMWidget({super.key});

  @override
  ConsumerState<TapBPMWidget> createState() => _TapBPMWidgetState();
}

class _TapBPMWidgetState extends ConsumerState<TapBPMWidget>
    with SingleTickerProviderStateMixin {
  final List<DateTime> _taps = [];
  int? _calculatedBPM;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: MonoPulseAnimation.durationShort,
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: MonoPulseAnimation.curveCustom,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTap() {
    final now = DateTime.now();

    // Trigger pulse animation
    _pulseController.forward(from: 0);
    HapticFeedback.lightImpact();

    // Add tap
    setState(() {
      _taps.add(now);

      // Keep only last 8 taps
      if (_taps.length > 8) {
        _taps.removeAt(0);
      }

      // Calculate BPM if we have at least 2 taps
      if (_taps.length >= 2) {
        final intervals = <int>[];
        for (int i = 1; i < _taps.length; i++) {
          intervals.add(_taps[i].difference(_taps[i - 1]).inMilliseconds);
        }

        // Average interval
        final avgInterval =
            intervals.reduce((a, b) => a + b) / intervals.length;

        // Convert to BPM
        final bpm = (60000 / avgInterval).round();

        // Validate BPM range
        if (bpm >= 40 && bpm <= 220) {
          _calculatedBPM = bpm;
        }
      }
    });
  }

  void _applyBPM() {
    if (_calculatedBPM != null) {
      HapticFeedback.mediumImpact();
      ref.read(metronomeProvider.notifier).setBpm(_calculatedBPM!);
      setState(() {
        _taps.clear();
        _calculatedBPM = null;
      });
    }
  }

  void _reset() {
    HapticFeedback.lightImpact();
    setState(() {
      _taps.clear();
      _calculatedBPM = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MonoPulseSpacing.lg),
      decoration: BoxDecoration(
        color: MonoPulseColors.surface,
        borderRadius: BorderRadius.circular(MonoPulseRadius.large),
        border: Border.all(color: MonoPulseColors.borderSubtle),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tap button
          GestureDetector(
            onTap: _handleTap,
            child: AnimatedScale(
              scale: _pulseController.isAnimating ? _pulseAnimation.value : 1.0,
              duration: MonoPulseAnimation.durationShort,
              curve: MonoPulseAnimation.curveCustom,
              child: Container(
                // Minimum 48px touch zone
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: MonoPulseColors.blackElevated,
                  border: Border.all(
                    color: _calculatedBPM != null
                        ? MonoPulseColors.accentOrange
                        : MonoPulseColors.borderDefault,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.touch_app,
                      size: 40,
                      color: _calculatedBPM != null
                          ? MonoPulseColors.accentOrange
                          : MonoPulseColors.textSecondary,
                    ),
                    const SizedBox(height: MonoPulseSpacing.sm),
                    Text(
                      'TAP',
                      style: MonoPulseTypography.labelLarge.copyWith(
                        color: _calculatedBPM != null
                            ? MonoPulseColors.accentOrange
                            : MonoPulseColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: MonoPulseSpacing.lg),

          // BPM display
          if (_calculatedBPM != null) ...[
            Text(
              '$_calculatedBPM BPM',
              style: MonoPulseTypography.headlineMedium.copyWith(
                color: MonoPulseColors.textHighEmphasis,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: MonoPulseSpacing.xs),
            Text(
              '${_taps.length} taps',
              style: MonoPulseTypography.bodySmall.copyWith(
                color: MonoPulseColors.textTertiary,
              ),
            ),
            const SizedBox(height: MonoPulseSpacing.lg),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ActionButton(
                  label: 'Apply',
                  icon: Icons.check,
                  isPrimary: true,
                  onTap: _applyBPM,
                ),
                const SizedBox(width: MonoPulseSpacing.md),
                _ActionButton(
                  label: 'Reset',
                  icon: Icons.refresh,
                  isPrimary: false,
                  onTap: _reset,
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: MonoPulseSpacing.sm),
            Text(
              'Tap to calculate tempo',
              style: MonoPulseTypography.bodySmall.copyWith(
                color: MonoPulseColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticFeedback.vibrate();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.vibrate();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: MonoPulseAnimation.durationShort,
        curve: MonoPulseAnimation.curveCustom,
        child: Container(
          // Minimum 48px touch zone
          padding: const EdgeInsets.symmetric(
            horizontal: MonoPulseSpacing.lg,
            vertical: MonoPulseSpacing.md,
          ),
          decoration: BoxDecoration(
            color: widget.isPrimary
                ? (_isPressed
                      ? MonoPulseColors.accentOrange.withValues(alpha: 0.8)
                      : MonoPulseColors.accentOrange)
                : MonoPulseColors.blackElevated,
            borderRadius: BorderRadius.circular(MonoPulseRadius.large),
            border: Border.all(
              color: widget.isPrimary
                  ? (_isPressed
                        ? MonoPulseColors.accentOrange
                        : MonoPulseColors.accentOrange)
                  : MonoPulseColors.borderDefault,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.isPrimary
                    ? MonoPulseColors.black
                    : MonoPulseColors.textSecondary,
              ),
              const SizedBox(width: MonoPulseSpacing.sm),
              Text(
                widget.label,
                style: MonoPulseTypography.labelLarge.copyWith(
                  color: widget.isPrimary
                      ? MonoPulseColors.black
                      : MonoPulseColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
