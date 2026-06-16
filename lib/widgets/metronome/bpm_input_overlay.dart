import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/tap_tempo_calculator.dart';
import '../../models/metronome_runtime_state.dart';
import '../../models/metronome_tempo_range.dart';
import '../../providers/data/metronome_provider.dart';
import '../../theme/mono_pulse_theme.dart';

/// Opens the tempo-input overlay shown when the dial centre is tapped.
///
/// Offers two ways to set the tempo: typing a BPM, or tapping it out.
Future<void> showTempoInputSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: MonoPulseColors.blackSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(MonoPulseRadius.xlarge),
      ),
    ),
    builder: (_) => const _TempoInputSheet(),
  );
}

class _TempoInputSheet extends ConsumerStatefulWidget {
  const _TempoInputSheet();

  @override
  ConsumerState<_TempoInputSheet> createState() => _TempoInputSheetState();
}

class _TempoInputSheetState extends ConsumerState<_TempoInputSheet> {
  int _mode = 0; // 0 = Enter, 1 = Tap

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: MonoPulseSpacing.lg,
        right: MonoPulseSpacing.lg,
        top: MonoPulseSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + MonoPulseSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: MonoPulseColors.borderDefault,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: MonoPulseSpacing.lg),
          _ModeToggle(
            mode: _mode,
            onChanged: (value) => setState(() => _mode = value),
          ),
          const SizedBox(height: MonoPulseSpacing.xl),
          if (_mode == 0) const _EnterBpmPanel() else const _TapTempoPanel(),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});

  final int mode;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: MonoPulseColors.surfaceRaised,
        borderRadius: BorderRadius.circular(MonoPulseRadius.large),
      ),
      child: Row(
        children: [
          _segment(label: 'Enter BPM', icon: Icons.keyboard, value: 0),
          _segment(label: 'Tap Tempo', icon: Icons.touch_app, value: 1),
        ],
      ),
    );
  }

  Widget _segment({
    required String label,
    required IconData icon,
    required int value,
  }) {
    final selected = mode == value;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: MonoPulseAnimation.durationShort,
          curve: MonoPulseAnimation.curveCustom,
          padding: const EdgeInsets.symmetric(vertical: MonoPulseSpacing.md),
          decoration: BoxDecoration(
            color: selected
                ? MonoPulseColors.accentOrange
                : Colors.transparent,
            borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? MonoPulseColors.black
                    : MonoPulseColors.textSecondary,
              ),
              const SizedBox(width: MonoPulseSpacing.sm),
              Text(
                label,
                style: MonoPulseTypography.labelMedium.copyWith(
                  color: selected
                      ? MonoPulseColors.black
                      : MonoPulseColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnterBpmPanel extends ConsumerStatefulWidget {
  const _EnterBpmPanel();

  @override
  ConsumerState<_EnterBpmPanel> createState() => _EnterBpmPanelState();
}

class _EnterBpmPanelState extends ConsumerState<_EnterBpmPanel> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(metronomeProvider).bpm.toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_controller.text);
    if (value != null) {
      ref.read(metronomeProvider.notifier).setBpm(
            MetronomeTempoRange.clamp(value),
          );
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: MonoPulseTypography.displayLarge.copyWith(
            color: MonoPulseColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: MonoPulseColors.surfaceRaised,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(MonoPulseRadius.large),
              borderSide: BorderSide.none,
            ),
            helperText:
                '${MetronomeTempoRange.minimum}-${MetronomeTempoRange.maximum} BPM',
            helperStyle: MonoPulseTypography.bodySmall.copyWith(
              color: MonoPulseColors.textTertiary,
            ),
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: MonoPulseSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: MonoPulseColors.accentOrange,
              foregroundColor: MonoPulseColors.black,
              padding: const EdgeInsets.symmetric(
                vertical: MonoPulseSpacing.md,
              ),
            ),
            onPressed: _submit,
            child: const Text('Set BPM'),
          ),
        ),
      ],
    );
  }
}

class _TapTempoPanel extends ConsumerStatefulWidget {
  const _TapTempoPanel();

  @override
  ConsumerState<_TapTempoPanel> createState() => _TapTempoPanelState();
}

class _TapTempoPanelState extends ConsumerState<_TapTempoPanel> {
  final TapTempoCalculator _calculator = TapTempoCalculator();
  int _tapCount = 0;
  int? _bpm;

  void _tap() {
    HapticFeedback.lightImpact();
    final bpm = _calculator.tap();
    setState(() {
      _tapCount = (_tapCount + 1).clamp(1, TapTempoCalculator.maxTaps);
      _bpm = bpm;
    });
    if (bpm != null) {
      ref
          .read(metronomeProvider.notifier)
          .setBpm(bpm, source: BpmSource.tapTempo);
    }
  }

  void _reset() {
    HapticFeedback.lightImpact();
    setState(() {
      _calculator.reset();
      _tapCount = 0;
      _bpm = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasBpm = _bpm != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _tap,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MonoPulseColors.blackElevated,
              border: Border.all(
                color: hasBpm
                    ? MonoPulseColors.accentOrange
                    : MonoPulseColors.borderDefault,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  hasBpm ? '$_bpm' : 'TAP',
                  style: MonoPulseTypography.displayMedium.copyWith(
                    color: hasBpm
                        ? MonoPulseColors.accentOrange
                        : MonoPulseColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  hasBpm ? 'BPM · $_tapCount taps' : 'tap the beat',
                  style: MonoPulseTypography.bodySmall.copyWith(
                    color: MonoPulseColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: MonoPulseSpacing.xl),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: hasBpm ? _reset : null,
                child: const Text('Reset'),
              ),
            ),
            const SizedBox(width: MonoPulseSpacing.md),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: MonoPulseColors.accentOrange,
                  foregroundColor: MonoPulseColors.black,
                ),
                onPressed: hasBpm
                    ? () => Navigator.of(context).maybePop()
                    : null,
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
