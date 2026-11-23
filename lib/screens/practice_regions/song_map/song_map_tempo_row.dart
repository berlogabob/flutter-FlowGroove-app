import 'package:material_ui/material_ui.dart';

import '../../../theme/mono_pulse_theme.dart';
import 'song_map_pads.dart';

/// The two whole-number tempos worth hearing for a detected grid, lower first.
///
/// Without a song BPM the detector's octave is a guess, so both octaves are
/// offered. With one, only an octave error (about half or double, within 4%)
/// qualifies. Otherwise there is nothing to ask.
({int a, int b})? songMapTempoOptions(double? detected, double? songBpm) {
  if (detected == null || !detected.isFinite || detected <= 0) return null;
  const tolerance = 0.04;
  bool near(double value, double target) =>
      (value - target).abs() <= tolerance * target;
  final double low;
  if (songBpm == null || !songBpm.isFinite || songBpm <= 0) {
    low = detected < 100 ? detected : detected / 2;
  } else if (near(detected, songBpm / 2)) {
    low = detected;
  } else if (near(detected, songBpm * 2)) {
    low = detected / 2;
  } else {
    return null;
  }
  return (a: low.round(), b: (low * 2).round());
}

/// `A | B | Other`: equal fixed-size keys; the chosen tempo is the lit key.
class SongMapTempoRow extends StatelessWidget {
  const SongMapTempoRow({
    required this.a,
    required this.b,
    required this.selected,
    required this.onChoose,
    required this.onOther,
    super.key,
  });

  static const keyHeight = MonoPulseSpacing.massive;
  static const height = keyHeight + 2 * MonoPulseSpacing.sm;

  final int a;
  final int b;
  final int? selected;
  final ValueChanged<int> onChoose;
  final VoidCallback onOther;

  @override
  Widget build(BuildContext context) {
    Widget tempoKey(String key, String label, bool on, VoidCallback? tap) =>
        Expanded(
          child: songMapKey(
            context,
            label,
            tap,
            key: ValueKey(key),
            selected: on,
            width: double.infinity,
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(
        left: MonoPulseSpacing.sm,
        right: MonoPulseSpacing.sm,
        top: MonoPulseSpacing.sm,
        bottom: MonoPulseSpacing.sm,
      ),
      child: Row(
        spacing: MonoPulseSpacing.sm,
        children: [
          tempoKey('tempo-a', '$a', selected == a, () => onChoose(a)),
          tempoKey('tempo-b', '$b', selected == b, () => onChoose(b)),
          tempoKey('tempo-other', 'Other', false, onOther),
        ],
      ),
    );
  }
}
