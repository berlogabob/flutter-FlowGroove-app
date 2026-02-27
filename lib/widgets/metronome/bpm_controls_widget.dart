import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data/metronome_provider.dart';
import '../../theme/mono_pulse_theme.dart';

/// BPM Controls widget - Slider, input field, and +/- buttons
/// Includes helpful tooltips explaining BPM concept
///
/// Mono Pulse Design (Sprint Fix):
/// - All colors from MonoPulseColors
/// - All typography from MonoPulseTypography
/// - All spacing from MonoPulseSpacing
/// - All radius from MonoPulseRadius
/// - Animations: 120ms, curveCustom
/// - Touch zones: 48x48px minimum
class BpmControlsWidget extends ConsumerStatefulWidget {
  const BpmControlsWidget({super.key});

  @override
  ConsumerState<BpmControlsWidget> createState() => _BpmControlsWidgetState();
}

class _BpmControlsWidgetState extends ConsumerState<BpmControlsWidget> {
  final _bpmController = TextEditingController();
  int _localBpm = 120;
  bool _isDecrementPressed = false;
  bool _isIncrementPressed = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(metronomeProvider);
    _localBpm = state.bpm;
    _bpmController.text = state.bpm.toString();
  }

  @override
  void didUpdateWidget(BpmControlsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final state = ref.read(metronomeProvider);
    if (state.bpm != _localBpm) {
      _localBpm = state.bpm;
      _bpmController.text = state.bpm.toString();
    }
  }

  @override
  void dispose() {
    _bpmController.dispose();
    super.dispose();
  }

  void _setBpm(int value) {
    final bpm = value.clamp(1, 300);
    setState(() {
      _localBpm = bpm;
      _bpmController.text = bpm.toString();
    });
    ref.read(metronomeProvider.notifier).setBpm(bpm);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(metronomeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.xxxl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Decrement button
          GestureDetector(
            onTapDown: (_) {
              setState(() => _isDecrementPressed = true);
              HapticFeedback.vibrate();
            },
            onTapUp: (_) {
              setState(() => _isDecrementPressed = false);
              HapticFeedback.vibrate();
              _setBpm(_localBpm - 1);
            },
            onTapCancel: () => setState(() => _isDecrementPressed = false),
            child: AnimatedScale(
              scale: _isDecrementPressed ? 0.95 : 1.0,
              duration: MonoPulseAnimation.durationShort,
              curve: MonoPulseAnimation.curveCustom,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: MonoPulseColors.blackElevated,
                  borderRadius: BorderRadius.circular(MonoPulseRadius.huge),
                  border: Border.all(
                    color: MonoPulseColors.borderSubtle,
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.remove,
                  color: MonoPulseColors.textSecondary,
                  size: 20,
                ),
              ),
            ),
          ),

          const SizedBox(width: MonoPulseSpacing.lg),

          // BPM display and slider
          Expanded(
            child: Column(
              children: [
                // BPM label with tooltip
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'BPM',
                      style: MonoPulseTypography.labelMedium.copyWith(
                        color: MonoPulseColors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: MonoPulseSpacing.xs),
                    Tooltip(
                      message:
                          'Beats Per Minute - Controls the tempo/speed of the metronome. Higher = faster, Lower = slower.',
                      preferBelow: false,
                      decoration: BoxDecoration(
                        color: MonoPulseColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(
                          MonoPulseRadius.medium,
                        ),
                      ),
                      textStyle: MonoPulseTypography.bodySmall.copyWith(
                        color: MonoPulseColors.textSecondary,
                      ),
                      child: const Icon(
                        Icons.help_outline,
                        size: 16,
                        color: MonoPulseColors.textTertiary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: MonoPulseSpacing.lg),

                // Slider
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    activeTrackColor: MonoPulseColors.accentOrange,
                    inactiveTrackColor: MonoPulseColors.borderDefault,
                    thumbColor: MonoPulseColors.accentOrange,
                    overlayColor: MonoPulseColors.accentOrange.withValues(
                      alpha: 0.2,
                    ),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 16,
                    ),
                  ),
                  child: Slider(
                    value: state.bpm.toDouble(),
                    min: 1,
                    max: 300,
                    divisions: 299,
                    onChanged: (value) => _setBpm(value.round()),
                  ),
                ),

                const SizedBox(height: MonoPulseSpacing.lg),

                // BPM value display
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${state.bpm}',
                      style: MonoPulseTypography.displayMedium.copyWith(
                        color: MonoPulseColors.textHighEmphasis,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: MonoPulseSpacing.md),
                    // BPM input field
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _bpmController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: MonoPulseTypography.bodyLarge.copyWith(
                          color: MonoPulseColors.textHighEmphasis,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: MonoPulseColors.surfaceRaised,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              MonoPulseRadius.medium,
                            ),
                            borderSide: const BorderSide(
                              color: MonoPulseColors.borderDefault,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              MonoPulseRadius.medium,
                            ),
                            borderSide: const BorderSide(
                              color: MonoPulseColors.borderDefault,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              MonoPulseRadius.medium,
                            ),
                            borderSide: const BorderSide(
                              color: MonoPulseColors.accentOrange,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: MonoPulseSpacing.md,
                            vertical: MonoPulseSpacing.sm,
                          ),
                          helperText: '1-600',
                          helperStyle: MonoPulseTypography.labelSmall.copyWith(
                            color: MonoPulseColors.textTertiary,
                          ),
                        ),
                        onChanged: (value) {
                          final bpm = int.tryParse(value);
                          if (bpm != null && bpm >= 1 && bpm <= 300) {
                            _setBpm(bpm);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: MonoPulseSpacing.lg),

          // Increment button
          GestureDetector(
            onTapDown: (_) {
              setState(() => _isIncrementPressed = true);
              HapticFeedback.vibrate();
            },
            onTapUp: (_) {
              setState(() => _isIncrementPressed = false);
              HapticFeedback.vibrate();
              _setBpm(_localBpm + 1);
            },
            onTapCancel: () => setState(() => _isIncrementPressed = false),
            child: AnimatedScale(
              scale: _isIncrementPressed ? 0.95 : 1.0,
              duration: MonoPulseAnimation.durationShort,
              curve: MonoPulseAnimation.curveCustom,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: MonoPulseColors.blackElevated,
                  borderRadius: BorderRadius.circular(MonoPulseRadius.huge),
                  border: Border.all(
                    color: MonoPulseColors.borderSubtle,
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.add,
                  color: MonoPulseColors.textSecondary,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
