import 'package:material_ui/material_ui.dart';

import '../../../services/audio/audio_analysis.dart';
import '../../../theme/mono_pulse_theme.dart';
import 'song_map_pads.dart';

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

  static const _lineHeight = 20.0;
  static const height =
      MonoPulseSpacing.sm +
      _lineHeight +
      MonoPulseSpacing.xs +
      MonoPulseSpacing.massive;

  final double measuredBpm;
  final VoidCallback onStretch;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    final target = songMapStretchTarget(measuredBpm);
    if (target == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(
        left: MonoPulseSpacing.sm,
        right: MonoPulseSpacing.sm,
        top: MonoPulseSpacing.sm,
      ),
      child: Column(
        spacing: MonoPulseSpacing.xs,
        children: [
          SizedBox(
            height: _lineHeight,
            width: double.infinity,
            child: Text(
              'Detected tempo $measuredBpm',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MonoPulseTypography.bodyMedium.copyWith(
                color: context.mp.textPrimary,
              ),
            ),
          ),
          Row(
            spacing: MonoPulseSpacing.sm,
            children: [
              Expanded(
                child: songMapKey(
                  context,
                  'Stretch to $target',
                  onStretch,
                  width: double.infinity,
                ),
              ),
              Expanded(
                child: songMapKey(
                  context,
                  'Keep',
                  onKeep,
                  width: double.infinity,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
