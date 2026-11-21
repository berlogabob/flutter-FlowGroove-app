import 'package:material_ui/material_ui.dart';

import '../../../services/audio/audio_analysis.dart';
import '../../../theme/mono_pulse_theme.dart';

int? songMapStretchTarget(double? measuredBpm) {
  if (measuredBpm == null || !measuredBpm.isFinite || measuredBpm < 0.5) {
    return null;
  }
  final whole = measuredBpm.round();
  return snapBpm(measuredBpm) == whole ? null : whole;
}

double songMapStretchFactor(double? measuredBpm) {
  final target = songMapStretchTarget(measuredBpm);
  return target == null ? 1 : target / measuredBpm!;
}

class SongMapTempoBanner extends StatelessWidget {
  const SongMapTempoBanner({
    required this.measuredBpm,
    required this.onStretch,
    required this.onKeep,
    super.key,
  });

  final double measuredBpm;
  final VoidCallback onStretch;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    final target = songMapStretchTarget(measuredBpm);
    if (target == null) return const SizedBox.shrink();
    final palette = context.mp;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.lg),
      padding: const EdgeInsets.all(MonoPulseSpacing.md),
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        border: Border.all(color: palette.borderSubtle),
        borderRadius: BorderRadius.circular(MonoPulseRadius.large),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Audio runs at $measuredBpm BPM · Stretch to $target / Keep',
            style: MonoPulseTypography.bodyMedium.copyWith(
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: MonoPulseSpacing.sm),
          Wrap(
            spacing: MonoPulseSpacing.sm,
            children: [
              OutlinedButton(
                onPressed: onStretch,
                child: Text('Stretch to $target'),
              ),
              TextButton(onPressed: onKeep, child: const Text('Keep')),
            ],
          ),
        ],
      ),
    );
  }
}
