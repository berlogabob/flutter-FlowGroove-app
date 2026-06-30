import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/section.dart';
import '../providers/wakelock_provider.dart';
import '../theme/mono_pulse_theme.dart';
import '../utils/chordpro.dart';
import '../widgets/chord_chart_view.dart';

/// Full-screen, stage-readable lyrics+chords view for a song. Renders each
/// section's ChordPro [Section.chordChart] as chords-over-lyrics, keeps the
/// screen awake while open, and supports live ± semitone transpose (display
/// only — not persisted).
class PerformanceSheetScreen extends ConsumerStatefulWidget {
  const PerformanceSheetScreen({
    required this.title,
    required this.sections,
    super.key,
  });

  final String title;
  final List<Section> sections;

  @override
  ConsumerState<PerformanceSheetScreen> createState() =>
      _PerformanceSheetScreenState();
}

class _PerformanceSheetScreenState
    extends ConsumerState<PerformanceSheetScreen> {
  int _transpose = 0;

  @override
  void initState() {
    super.initState();
    ref.read(wakelockProvider).enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    ref.read(wakelockProvider).disable();
    super.dispose();
  }

  String get _transposeLabel {
    if (_transpose == 0) return 'Original';
    return _transpose > 0 ? '+$_transpose' : '$_transpose';
  }

  @override
  Widget build(BuildContext context) {
    final withCharts = widget.sections
        .where((s) =>
            (s.chordChart != null && s.chordChart!.trim().isNotEmpty) ||
            s.notes.trim().isNotEmpty)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Transpose down',
            icon: const Icon(Icons.remove),
            onPressed: () => setState(() => _transpose--),
          ),
          Center(
            child: Text(
              _transposeLabel,
              style: MonoPulseTypography.labelLarge,
            ),
          ),
          IconButton(
            tooltip: 'Transpose up',
            icon: const Icon(Icons.add),
            onPressed: () => setState(() => _transpose++),
          ),
          const SizedBox(width: MonoPulseSpacing.sm),
        ],
      ),
      body: withCharts.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(MonoPulseSpacing.lg),
              itemCount: withCharts.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: MonoPulseSpacing.xl),
              itemBuilder: (context, i) =>
                  _SectionBlock(section: withCharts[i], transpose: _transpose),
            ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({required this.section, required this.transpose});

  final Section section;
  final int transpose;

  @override
  Widget build(BuildContext context) {
    final chart = section.chordChart?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.name,
          style: MonoPulseTypography.titleMedium.copyWith(
            color: MonoPulseColors.accentOrange,
          ),
        ),
        const SizedBox(height: MonoPulseSpacing.sm),
        if (chart.isNotEmpty)
          ChordChartView(
            chart: transposeChordChart(chart, transpose),
            lyricStyle: Theme.of(context).textTheme.headlineSmall,
          )
        else
          // No ChordPro yet — fall back to plain section notes.
          Text(section.notes, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MonoPulseSpacing.xl),
        child: Text(
          'No lyrics or chords yet.\nAdd them to a section to see the '
          'performance sheet.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: MonoPulseColors.textSecondary,
              ),
        ),
      ),
    );
  }
}
