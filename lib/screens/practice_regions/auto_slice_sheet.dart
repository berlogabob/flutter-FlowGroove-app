import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/audio_region.dart';
import '../../services/audio/audio_analysis.dart';
import '../../services/audio/song_structure.dart'
    show SongStructure, analyseStructure;
import '../../theme/mono_pulse_theme.dart';

SongStructure? analyseStructureRequest((Int16List, AudioGrid) request) =>
    analyseStructure(request.$1, 22050, request.$2);

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
  var parts = true;
  SongStructure? structure;
  Future<Int16List?>? structureFuture;
  ({double bpm, int firstDownbeatMs})? suggestion;
  final pcmFuture = ensurePcm().then((pcm) {
    if (pcm != null && pcm.isNotEmpty) {
      suggestion = estimateGrid(pcm, 22050, hintBpm: songBpm());
    }
    return pcm;
  });
  final result = await showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.mp.surface,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, sheetSetState) => FutureBuilder<Int16List?>(
        future: mode == 3 && grid != null
            ? structureFuture ??= pcmFuture.then((pcm) async {
                if (pcm != null && pcm.isNotEmpty) {
                  structure = await compute(analyseStructureRequest, (
                    pcm,
                    grid,
                  ));
                }
                return pcm;
              })
            : pcmFuture,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState != ConnectionState.done;
          final pcm = snapshot.data;
          final hasPcm = pcm != null && pcm.isNotEmpty;
          final structureRegions = structure == null
              ? <AudioRegion>[]
              : parts
              ? regionsFromStructure(structure!, newId: () => '')
              : [
                  for (final section in structure!.sections)
                    AudioRegion(
                      id: '',
                      name: section.name,
                      section: section.name,
                      startMs: section.startMs,
                      endMs: section.endMs,
                    ),
                ];
          if (mode == 3 && grid == null && hasPcm && found == null) {
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
          final count = mode == 3 && grid != null
              ? structureRegions.length
              : regionsFromCuts(
                  cuts,
                  durationMs: durationMs(),
                  newId: () => '',
                ).length;
          final canApply = mode == 0
              ? !loading && suggestion != null
              : mode == 1
              ? grid != null
              : mode == 3 && grid != null
              ? !loading && structure != null
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
                    if (mode == 3 && grid != null)
                      Wrap(
                        spacing: MonoPulseSpacing.sm,
                        children: [
                          for (final (value, label) in [
                            (false, 'Sections'),
                            (true, 'Parts'),
                          ])
                            ChoiceChip(
                              label: Text(label),
                              selected: parts == value,
                              onSelected: (_) =>
                                  sheetSetState(() => parts = value),
                            ),
                        ],
                      ),
                    if (mode == 3 &&
                        grid != null &&
                        !loading &&
                        hasPcm &&
                        structure == null)
                      const Text('Not enough audio to find sections.'),
                    if (mode == 3 && grid == null && found != null)
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
                                    : mode == 3 && grid != null
                                    ? structureRegions
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
