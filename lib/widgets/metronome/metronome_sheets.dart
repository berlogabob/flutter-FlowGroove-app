import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/metronome_tempo_range.dart';
import '../../models/tempo_ramp.dart';
import '../../providers/data/metronome_provider.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/snackbar.dart';

/// Shared bottom-sheet launcher for the metronome tool panels.
Future<void> _showSheet(BuildContext context, Widget child) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.mp.blackSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(MonoPulseRadius.xlarge),
      ),
    ),
    builder: (_) => child,
  );
}

/// Consistent header + scrollable body wrapper for a tool sheet.
class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({required this.title, required this.children});

  final String title;
  final List<Widget> children;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.mp.borderDefault,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: MonoPulseSpacing.lg),
          Text(
            title,
            style: MonoPulseTypography.headlineSmall.copyWith(
              color: context.mp.textHighEmphasis,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: MonoPulseSpacing.lg),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// SOUND SHEET
// ===========================================================================

Future<void> showSoundSheet(BuildContext context) =>
    _showSheet(context, const _SoundSheet());

class _SoundSheet extends ConsumerWidget {
  const _SoundSheet();

  static const List<String> _waveTypes = [
    'sine',
    'square',
    'triangle',
    'sawtooth',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(metronomeProvider);
    final notifier = ref.read(metronomeProvider.notifier);

    return _SheetScaffold(
      title: 'Sound',
      children: [
        const _SheetLabel('Click sound'),
        const SizedBox(height: MonoPulseSpacing.sm),
        Wrap(
          spacing: MonoPulseSpacing.sm,
          runSpacing: MonoPulseSpacing.sm,
          children: _waveTypes.map((type) {
            final selected = state.waveType.toLowerCase() == type;
            return ChoiceChip(
              label: Text(_capitalize(type)),
              selected: selected,
              onSelected: (_) {
                notifier.setWaveType(type);
                HapticFeedback.selectionClick();
              },
              selectedColor: MonoPulseColors.accentOrange,
              backgroundColor: context.mp.surfaceRaised,
              labelStyle: MonoPulseTypography.labelMedium.copyWith(
                color: selected ? context.mp.black : context.mp.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(
                color: selected
                    ? MonoPulseColors.accentOrange
                    : context.mp.borderSubtle,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: MonoPulseSpacing.lg),
        _SliderRow(
          label: 'Volume',
          value: state.volume,
          min: 0,
          max: 1,
          display: '${(state.volume * 100).round()}%',
          onChanged: notifier.setVolume,
        ),
        _SliderRow(
          label: 'Primary pitch',
          value: state.accentFrequency.clamp(400, 2000),
          min: 400,
          max: 2000,
          display: '${state.accentFrequency.round()} Hz',
          onChanged: notifier.setAccentFrequency,
        ),
        _SliderRow(
          label: 'Subdivision pitch',
          value: state.beatFrequency.clamp(200, 1500),
          min: 200,
          max: 1500,
          display: '${state.beatFrequency.round()} Hz',
          onChanged: notifier.setBeatFrequency,
        ),
        _SliderRow(
          label: 'Subdivision volume',
          value: state.subdivisionGain.clamp(0.5, 2.0),
          min: 0.5,
          max: 2.0,
          display: '${(state.subdivisionGain * 100).round()}%',
          onChanged: notifier.setSubdivisionGain,
        ),
        _SliderRow(
          label: 'Accent pitch',
          value: state.accentBeatFrequency.clamp(400, 3000),
          min: 400,
          max: 3000,
          display: '${state.accentBeatFrequency.round()} Hz',
          onChanged: notifier.setAccentBeatFrequency,
          accentColor: MonoPulseColors.beatModeAccent,
        ),
        Divider(color: context.mp.borderSubtle, height: 1),
        _SwitchRow(
          label: 'Visual flash',
          icon: Icons.flash_on,
          value: state.visualFlashEnabled,
          onChanged: notifier.setVisualFlashEnabled,
        ),
        _SwitchRow(
          label: 'Haptics',
          icon: Icons.vibration,
          value: state.hapticsEnabled,
          onChanged: notifier.setHapticsEnabled,
        ),
      ],
    );
  }
}

// ===========================================================================
// COUNT-IN SHEET
// ===========================================================================

Future<void> showCountInSheet(BuildContext context) =>
    _showSheet(context, const _CountInSheet());

class _CountInSheet extends ConsumerWidget {
  const _CountInSheet();

  static const List<int> _options = [0, 1, 2, 4];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countInBars = ref.watch(
      metronomeProvider.select((s) => s.countInBars),
    );
    final notifier = ref.read(metronomeProvider.notifier);
    return _SheetScaffold(
      title: 'Count-in',
      children: [
        const _SheetLabel('Silent bars before playback starts'),
        const SizedBox(height: MonoPulseSpacing.md),
        Wrap(
          spacing: MonoPulseSpacing.sm,
          children: _options.map((value) {
            final selected = countInBars == value;
            return ChoiceChip(
              label: Text(
                value == 0 ? 'Off' : '$value bar${value > 1 ? 's' : ''}',
              ),
              selected: selected,
              onSelected: (_) {
                notifier.setCountInBars(value);
                HapticFeedback.selectionClick();
              },
              selectedColor: MonoPulseColors.accentOrange,
              backgroundColor: context.mp.surfaceRaised,
              labelStyle: MonoPulseTypography.labelMedium.copyWith(
                color: selected ? context.mp.black : context.mp.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(
                color: selected
                    ? MonoPulseColors.accentOrange
                    : context.mp.borderSubtle,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ===========================================================================
// TEMPO RAMP SHEET
// ===========================================================================

Future<void> showRampSheet(BuildContext context) =>
    _showSheet(context, const _RampSheet());

class _RampSheet extends ConsumerStatefulWidget {
  const _RampSheet();

  @override
  ConsumerState<_RampSheet> createState() => _RampSheetState();
}

class _RampSheetState extends ConsumerState<_RampSheet> {
  late final TextEditingController _target;
  late final TextEditingController _step;
  late final TextEditingController _every;
  TempoRampCadence _cadence = TempoRampCadence.bars;
  bool _loop = false;

  @override
  void initState() {
    super.initState();
    final bpm = ref.read(metronomeProvider).bpm;
    _target = TextEditingController(
      text: '${MetronomeTempoRange.clamp(bpm + 20)}',
    );
    _step = TextEditingController(text: '2');
    _every = TextEditingController(text: '4');
  }

  @override
  void dispose() {
    _target.dispose();
    _step.dispose();
    _every.dispose();
    super.dispose();
  }

  void _start() {
    final start = ref.read(metronomeProvider).bpm;
    final target = int.tryParse(_target.text);
    final step = int.tryParse(_step.text);
    final every = int.tryParse(_every.text);
    if (target == null || step == null || every == null) return;
    try {
      final ramp = TempoRamp(
        id: const Uuid().v4(),
        name: '$start → $target BPM',
        startBpm: start,
        targetBpm: target,
        stepBpm: step,
        cadence: _cadence,
        every: every,
        loop: _loop,
      )..validate();
      ref.read(metronomeProvider.notifier).startTempoRamp(ramp);
      Navigator.of(context).maybePop();
    } on ArgumentError catch (e) {
      showAppSnackBar(context, e.message.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final rampActive = ref.watch(
      metronomeProvider.select((s) => s.activeTempoRamp != null),
    );
    if (rampActive) {
      return _SheetScaffold(
        title: 'Tempo ramp',
        children: [
          const _SheetLabel('A tempo ramp is running.'),
          const SizedBox(height: MonoPulseSpacing.lg),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: context.mp.surfaceRaised,
              foregroundColor: context.mp.textPrimary,
            ),
            icon: const Icon(Icons.stop),
            label: const Text('Stop ramp'),
            onPressed: () {
              ref.read(metronomeProvider.notifier).stopTempoRamp();
              Navigator.of(context).maybePop();
            },
          ),
        ],
      );
    }

    return _SheetScaffold(
      title: 'Tempo ramp',
      children: [
        const _SheetLabel('Gradually change tempo from now to a target.'),
        const SizedBox(height: MonoPulseSpacing.md),
        Row(
          children: [
            Expanded(
              child: _NumField(label: 'Target BPM', controller: _target),
            ),
            const SizedBox(width: MonoPulseSpacing.md),
            Expanded(
              child: _NumField(label: 'Step', controller: _step),
            ),
            const SizedBox(width: MonoPulseSpacing.md),
            Expanded(
              child: _NumField(label: 'Every', controller: _every),
            ),
          ],
        ),
        const SizedBox(height: MonoPulseSpacing.lg),
        const _SheetLabel('Advance every'),
        const SizedBox(height: MonoPulseSpacing.sm),
        SegmentedButton<TempoRampCadence>(
          segments: const [
            ButtonSegment(value: TempoRampCadence.bars, label: Text('Bars')),
            ButtonSegment(
              value: TempoRampCadence.seconds,
              label: Text('Seconds'),
            ),
          ],
          selected: {_cadence},
          onSelectionChanged: (s) => setState(() => _cadence = s.first),
        ),
        _SwitchRow(
          label: 'Loop',
          icon: Icons.loop,
          value: _loop,
          onChanged: (v) => setState(() => _loop = v),
        ),
        const SizedBox(height: MonoPulseSpacing.md),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: MonoPulseColors.accentOrange,
            foregroundColor: context.mp.black,
          ),
          icon: const Icon(Icons.trending_up),
          label: const Text('Start ramp'),
          onPressed: _start,
        ),
      ],
    );
  }
}

// ===========================================================================
// SHARED CONTROLS
// ===========================================================================

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: MonoPulseTypography.bodySmall.copyWith(
        color: context.mp.textTertiary,
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
    this.accentColor,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  /// Active color for the value readout and slider track. Defaults to the
  /// standard orange accent; the marked-accent pitch row passes the cyan
  /// beat-map color so the control reads as the accent control.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? MonoPulseColors.accentOrange;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: MonoPulseTypography.labelMedium.copyWith(
                color: context.mp.textSecondary,
              ),
            ),
            Text(
              display,
              style: MonoPulseTypography.labelMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          activeColor: color,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MonoPulseSpacing.xs),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: value
                ? MonoPulseColors.accentOrange
                : context.mp.textTertiary,
          ),
          const SizedBox(width: MonoPulseSpacing.md),
          Expanded(
            child: Text(
              label,
              style: MonoPulseTypography.bodyMedium.copyWith(
                color: context.mp.textHighEmphasis,
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: MonoPulseColors.accentOrange,
            onChanged: (v) {
              onChanged(v);
              HapticFeedback.selectionClick();
            },
          ),
        ],
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: context.mp.surfaceRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
