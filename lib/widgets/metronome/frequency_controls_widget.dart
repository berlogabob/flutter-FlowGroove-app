import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data/metronome_provider.dart';
import '../../theme/mono_pulse_theme.dart';

/// Frequency Controls widget - Sound settings (ADVANCED)
/// Contains: Wave type selector, volume slider, accent toggle, frequency inputs
/// Now collapsible to hide advanced settings from casual users
///
/// Mono Pulse Design (Sprint Fix):
/// - All colors from MonoPulseColors
/// - All typography from MonoPulseTypography
/// - All spacing from MonoPulseSpacing
/// - All radius from MonoPulseRadius
/// - Animations: 120-300ms, curveCustom
/// - Touch zones: 48x48px minimum
class FrequencyControlsWidget extends ConsumerStatefulWidget {
  const FrequencyControlsWidget({super.key});

  @override
  ConsumerState<FrequencyControlsWidget> createState() =>
      _FrequencyControlsWidgetState();
}

class _FrequencyControlsWidgetState
    extends ConsumerState<FrequencyControlsWidget> {
  late TextEditingController _accentFreqController;
  late TextEditingController _beatFreqController;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(metronomeProvider);
    _accentFreqController = TextEditingController(
      text: state.accentFrequency.toString(),
    );
    _beatFreqController = TextEditingController(
      text: state.beatFrequency.toString(),
    );
  }

  @override
  void didUpdateWidget(FrequencyControlsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final state = ref.read(metronomeProvider);
    if (_accentFreqController.text != state.accentFrequency.toString()) {
      _accentFreqController.text = state.accentFrequency.toString();
    }
    if (_beatFreqController.text != state.beatFrequency.toString()) {
      _beatFreqController.text = state.beatFrequency.toString();
    }
  }

  @override
  void dispose() {
    _accentFreqController.dispose();
    _beatFreqController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metronome = ref.watch(metronomeProvider.notifier);
    final state = ref.watch(metronomeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.xxxl),
      child: Container(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        decoration: BoxDecoration(
          color: MonoPulseColors.surface,
          borderRadius: BorderRadius.circular(MonoPulseRadius.large),
          border: Border.all(color: MonoPulseColors.borderSubtle),
        ),
        child: Column(
          children: [
            // Collapsible Advanced Settings Header
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: MonoPulseSpacing.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                          color: MonoPulseColors.textSecondary,
                        ),
                        const SizedBox(width: MonoPulseSpacing.sm),
                        Text(
                          'Advanced Settings',
                          style: MonoPulseTypography.labelLarge.copyWith(
                            color: MonoPulseColors.textHighEmphasis,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const Icon(
                      Icons.tune,
                      size: 20,
                      color: MonoPulseColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),

            // Collapsible Content
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  const Divider(
                    color: MonoPulseColors.borderSubtle,
                    height: 1,
                    thickness: 1,
                  ),
                  const SizedBox(height: MonoPulseSpacing.lg),

                  // Tone Type Selector with User-Friendly Labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Tone: ',
                        style: MonoPulseTypography.labelMedium.copyWith(
                          color: MonoPulseColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: MonoPulseSpacing.sm),
                      _WaveTypeDropdown(
                        value: state.waveType,
                        onChanged: (value) {
                          HapticFeedback.lightImpact();
                          if (value != null) {
                            metronome.setWaveType(value);
                          }
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: MonoPulseSpacing.lg),

                  // Volume Slider
                  Row(
                    children: [
                      const Icon(
                        Icons.volume_up,
                        size: 20,
                        color: MonoPulseColors.textSecondary,
                      ),
                      const SizedBox(width: MonoPulseSpacing.md),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 2,
                            activeTrackColor: MonoPulseColors.accentOrange,
                            inactiveTrackColor: MonoPulseColors.borderDefault,
                            thumbColor: MonoPulseColors.accentOrange,
                            overlayColor: MonoPulseColors.accentOrange
                                .withValues(alpha: 0.2),
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 16,
                            ),
                          ),
                          child: Slider(
                            value: state.volume,
                            min: 0.0,
                            max: 1.0,
                            divisions: 10,
                            label: '${(state.volume * 100).round()}%',
                            onChanged: (value) {
                              HapticFeedback.lightImpact();
                              metronome.setVolume(value);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: MonoPulseSpacing.md),
                      Text(
                        '${(state.volume * 100).round()}%',
                        style: MonoPulseTypography.labelMedium.copyWith(
                          color: MonoPulseColors.textTertiary,
                        ),
                      ),
                    ],
                  ),

                  // Accent Toggle
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: MonoPulseSpacing.sm,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Accent on beat 1',
                              style: MonoPulseTypography.bodyMedium.copyWith(
                                color: MonoPulseColors.textHighEmphasis,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Higher pitch on first beat',
                              style: MonoPulseTypography.bodySmall.copyWith(
                                color: MonoPulseColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                        _OrangeSwitch(
                          value: state.accentEnabled,
                          onChanged: (value) {
                            HapticFeedback.lightImpact();
                            metronome.setAccentEnabled(value);
                          },
                        ),
                      ],
                    ),
                  ),

                  const Divider(
                    color: MonoPulseColors.borderSubtle,
                    height: 1,
                    thickness: 1,
                  ),
                  const SizedBox(height: MonoPulseSpacing.lg),

                  Text(
                    'Frequencies (Hz)',
                    style: MonoPulseTypography.labelLarge.copyWith(
                      color: MonoPulseColors.textHighEmphasis,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: MonoPulseSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Accent:',
                              style: MonoPulseTypography.labelMedium.copyWith(
                                color: MonoPulseColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: MonoPulseSpacing.xs),
                            TextField(
                              controller: _accentFreqController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: MonoPulseTypography.bodyMedium.copyWith(
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
                              ),
                              onChanged: (value) {
                                final freq = double.tryParse(value);
                                if (freq != null) {
                                  metronome.setAccentFrequency(freq);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: MonoPulseSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Beat:',
                              style: MonoPulseTypography.labelMedium.copyWith(
                                color: MonoPulseColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: MonoPulseSpacing.xs),
                            TextField(
                              controller: _beatFreqController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: MonoPulseTypography.bodyMedium.copyWith(
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
                              ),
                              onChanged: (value) {
                                final freq = double.tryParse(value);
                                if (freq != null) {
                                  metronome.setBeatFrequency(freq);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: MonoPulseAnimation.durationMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveTypeDropdown extends StatelessWidget {
  final String value;
  final Function(String?) onChanged;

  const _WaveTypeDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MonoPulseSpacing.md,
        vertical: MonoPulseSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: MonoPulseColors.surfaceRaised,
        borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
        border: Border.all(color: MonoPulseColors.borderDefault, width: 1),
      ),
      child: DropdownButton<String>(
        value: value,
        underline: const SizedBox.shrink(),
        icon: const Icon(
          Icons.arrow_drop_down,
          color: MonoPulseColors.textSecondary,
          size: 20,
        ),
        items: const [
          DropdownMenuItem(value: 'sine', child: Text('Smooth')),
          DropdownMenuItem(value: 'square', child: Text('Sharp')),
          DropdownMenuItem(value: 'triangle', child: Text('Soft')),
          DropdownMenuItem(value: 'sawtooth', child: Text('Bright')),
        ],
        onChanged: onChanged,
        style: MonoPulseTypography.bodyMedium.copyWith(
          color: MonoPulseColors.textHighEmphasis,
        ),
      ),
    );
  }
}

class _OrangeSwitch extends StatelessWidget {
  final bool value;
  final Function(bool) onChanged;

  const _OrangeSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: MonoPulseColors.accentOrange,
      activeTrackColor: MonoPulseColors.accentOrange.withValues(alpha: 0.5),
      inactiveThumbColor: MonoPulseColors.textTertiary,
      inactiveTrackColor: MonoPulseColors.borderDefault,
    );
  }
}
