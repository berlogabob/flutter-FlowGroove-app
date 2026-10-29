import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/audio_region.dart';
import '../../services/audio/audio_analysis.dart';
import '../../theme/mono_pulse_theme.dart';

Future<Object?> showAutoSliceSheet(
  BuildContext context, {
  required AudioGrid? grid,
  required Future<Int16List?> Function() ensurePcm,
  required double? Function() songBpm,
  required int Function() durationMs,
  required bool Function() snap,
  required String Function(int) time,
  int Function() songSections = _none,
}) async {
  var mode = 0;
  var everyBars = 4;
  var sensitivity = 1.5;
  List<({int ms, double strength})>? found;
  var foundCuts = 0;
  ({double bpm, int firstDownbeatMs})? suggestion;
  final pcmFuture = ensurePcm().then((pcm) {
    if (pcm != null && pcm.isNotEmpty)
      suggestion = estimateGrid(pcm, 22050, hintBpm: songBpm());
    return pcm;
  });
  final result = await showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.mp.surface,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, sheetSetState) => FutureBuilder<Int16List?>(
        future: pcmFuture,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState != ConnectionState.done;
          final pcm = snapshot.data;
          final hasPcm = pcm != null && pcm.isNotEmpty;
          if (mode == 3 && hasPcm && found == null) {
            found = sectionCuts(pcm, 22050, grid: grid);
            foundCuts = suggestedSectionCuts(
              found!,
              songSections: songSections(),
            );
          }
          final cuts = mode == 1 && grid != null
              ? gridCuts(grid, everyBars: everyBars, durationMs: durationMs())
              : mode == 3 && found != null
              ? topSectionCuts(found!, foundCuts)
              : mode == 2 && hasPcm
              ? detectOnsets(
                      pcm,
                      22050,
                      sensitivity: sensitivity,
                      minGapMs: 250,
                    )
                    .map(
                      (ms) => snap() && grid != null
                          ? grid.snap(ms, durationMs: durationMs())
                          : ms,
                    )
                    .toList()
              : <int>[];
          final count = regionsFromCuts(
            cuts,
            durationMs: durationMs(),
            newId: () => '',
          ).length;
          final canApply = mode == 0
              ? !loading && suggestion != null
              : mode == 1
              ? grid != null
              : !loading && hasPcm;
          return Padding(
            padding: const EdgeInsets.all(MonoPulseSpacing.lg),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Auto slice',
                      style: MonoPulseTypography.titleLarge,
                    ),
                    Wrap(
                      spacing: MonoPulseSpacing.sm,
                      children: [
                        for (final (i, label) in [
                          (0, 'Suggest tempo grid'),
                          (1, 'Slice every N bars'),
                          (2, 'Chop by transients'),
                          (3, 'Find sections'),
                        ])
                          ChoiceChip(
                            label: Text(label),
                            selected: mode == i,
                            onSelected: (_) => sheetSetState(() => mode = i),
                          ),
                      ],
                    ),
                    if (loading && mode != 1)
                      const Center(child: CircularProgressIndicator()),
                    if (!loading && !hasPcm && mode != 1)
                      const Text('Audio could not be decoded for analysis.'),
                    if (mode == 0 && !loading && hasPcm)
                      Text(
                        suggestion == null
                            ? 'Not enough audio to suggest a tempo grid.'
                            : '${suggestion!.bpm.toStringAsFixed(1)} BPM · downbeat '
                                  '${time(suggestion!.firstDownbeatMs)}.'
                                  '${(suggestion!.firstDownbeatMs % 1000).toString().padLeft(3, '0')}',
                      ),
                    if (mode == 1) ...[
                      if (grid == null) const Text('Set a tempo grid first.'),
                      Wrap(
                        spacing: MonoPulseSpacing.sm,
                        children: [
                          for (final bars in [1, 2, 4, 8, 16, 24, 32])
                            ChoiceChip(
                              label: Text('$bars'),
                              selected: everyBars == bars,
                              onSelected: grid == null
                                  ? null
                                  : (_) =>
                                        sheetSetState(() => everyBars = bars),
                            ),
                        ],
                      ),
                    ],
                    if (mode == 2) ...[
                      Text('Sensitivity ${sensitivity.toStringAsFixed(1)}'),
                      Slider(
                        value: sensitivity,
                        min: 0.5,
                        max: 3,
                        onChanged: hasPcm
                            ? (value) =>
                                  sheetSetState(() => sensitivity = value)
                            : null,
                      ),
                    ],
                    if (mode == 3 && found != null)
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Fewer sections',
                            onPressed: foundCuts > 0
                                ? () => sheetSetState(() => foundCuts--)
                                : null,
                            icon: const Icon(Icons.remove),
                          ),
                          const Text('Fewer · More'),
                          IconButton(
                            tooltip: 'More sections',
                            onPressed: foundCuts < found!.length
                                ? () => sheetSetState(() => foundCuts++)
                                : null,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    if (mode != 0 && canApply) Text('$count slices'),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: !canApply
                            ? null
                            : () => Navigator.pop(
                                sheetContext,
                                mode == 0
                                    ? AudioGrid(
                                        bpm: suggestion!.bpm,
                                        offsetMs: suggestion!.firstDownbeatMs,
                                      )
                                    : cuts,
                              ),
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
  return result;
}

int _none() => 0;
