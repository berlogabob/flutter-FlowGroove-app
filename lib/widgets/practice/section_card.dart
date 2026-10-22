import 'package:flutter/material.dart';

import '../../models/section.dart';
import '../../theme/mono_pulse_theme.dart';
import '../chord_chart_view.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({required this.section, this.queued = false, super.key});

  final Section section;
  final bool queued;

  @override
  Widget build(BuildContext context) {
    final chart = section.chordChart?.trim() ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${section.name} · ${queued ? 'Next bar' : 'Playing'}',
              style: MonoPulseTypography.titleMedium.copyWith(
                color: section.color,
              ),
            ),
            if (chart.isNotEmpty) ...[
              const SizedBox(height: MonoPulseSpacing.sm),
              ChordChartView(chart: chart),
            ],
          ],
        ),
      ),
    );
  }
}
