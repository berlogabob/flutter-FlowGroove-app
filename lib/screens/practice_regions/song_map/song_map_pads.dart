import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../models/audio_region.dart';
import '../../../theme/mono_pulse_theme.dart';
import 'song_map_view.dart';

/// Practice pads for the current level of a [SongMapView].
class SongMapPads extends StatefulWidget {
  const SongMapPads({
    required this.view,
    this.actions = const [],
    this.selectedIndex,
    this.selectedIndices = const {},
    this.playingIndex,
    this.queuedIndex,
    this.disabledIndices = const {},
    this.progress = 0,
    this.onSelect,
    this.onHold,
    this.onRange,
    super.key,
  });

  static const padHeight = 64.0;
  static double heightForRows(int rows) =>
      48 + rows * padHeight + (rows + 1) * MonoPulseSpacing.sm;

  static int columnsForWidth(double width) => width >= 360 ? 4 : 3;

  final SongMapView view;
  final List<Widget> actions;
  final int? selectedIndex;
  final Set<int> selectedIndices;
  final int? playingIndex;
  final int? queuedIndex;
  final Set<int> disabledIndices;
  final double progress;
  final ValueChanged<int>? onSelect;
  final ValueChanged<int>? onHold;
  final ValueChanged<(int, int)>? onRange;

  @override
  State<SongMapPads> createState() => _SongMapPadsState();
}

class _SongMapPadsState extends State<SongMapPads> {
  bool _rangeMode = false;
  int? _rangeStart;
  final _held = <int, int>{};
  bool _runMade = false;

  void _release(int pointer) {
    _held.remove(pointer);
    if (_held.isEmpty && _runMade) {
      scheduleMicrotask(() => _runMade = false);
    }
  }

  int _bars(AudioRegion region) {
    final grid = widget.view.grid;
    if (grid == null || grid.barMs <= 0) return 0;
    return (grid.barAt(region.endMs).round() -
            grid.barAt(region.startMs).round())
        .abs()
        .clamp(1, 9999);
  }

  Color _sectionColor(int index) => switch (index % 7) {
    0 => MonoPulseColors.section1,
    1 => MonoPulseColors.section3,
    2 => MonoPulseColors.section5,
    3 => MonoPulseColors.section7,
    4 => MonoPulseColors.section9,
    5 => MonoPulseColors.section11,
    _ => MonoPulseColors.section13,
  };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.view,
    builder: (context, _) {
      final children = widget.view.children();
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MonoPulseSpacing.lg,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.view.level == SongMapZoom.song
                          ? 'Sections'
                          : 'Practice pads',
                      style: MonoPulseTypography.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.onRange != null)
                    TextButton(
                      onPressed: () => setState(() {
                        _rangeMode = !_rangeMode;
                        _rangeStart = null;
                      }),
                      child: Text(_rangeMode ? 'Range: on' : 'Range'),
                    ),
                  if (widget.view.level != SongMapZoom.song)
                    IconButton(
                      tooltip: 'Zoom out',
                      onPressed: widget.view.zoomOut,
                      icon: const Icon(Icons.zoom_out),
                    ),
                  ...widget.actions,
                ],
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = SongMapPads.columnsForWidth(
                  constraints.maxWidth,
                );
                const gap = MonoPulseSpacing.sm;
                const inset = MonoPulseSpacing.lg;
                final padWidth =
                    (constraints.maxWidth - 2 * inset - (columns - 1) * gap) /
                    columns;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: inset,
                    vertical: gap,
                  ),
                  child: Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final (index, region) in children.indexed)
                        _pad(context, region, index, padWidth),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      );
    },
  );

  Widget _pad(
    BuildContext context,
    AudioRegion region,
    int index,
    double width,
  ) {
    final disabled = widget.disabledIndices.contains(index);
    final playing = widget.playingIndex == index;
    final queued = widget.queuedIndex == index;
    final selected =
        widget.selectedIndex == index ||
        widget.selectedIndices.contains(index) ||
        _rangeStart == index;
    final accent = _sectionColor(index);
    final bars = _bars(region);
    final subtitle = region.skip
        ? 'Skipped'
        : region.lengthMs < (widget.view.grid?.barMs ?? 2000)
        ? '⚠ ${(region.lengthMs / 1000).toStringAsFixed(1)} s'
        : bars > 0
        ? '$bars bars'
        : '${(region.lengthMs / 1000).round()} s';
    final bg = playing ? MonoPulseColors.accentOrange : context.mp.surface;
    final fg = playing ? MonoPulseColors.charcoal : context.mp.textPrimary;
    final pad = Opacity(
      opacity: disabled || region.skip ? .38 : 1,
      child: SizedBox(
        width: width,
        height: SongMapPads.padHeight,
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MonoPulseRadius.large),
            side: BorderSide(
              color: playing || queued
                  ? MonoPulseColors.accentOrange
                  : selected
                  ? context.mp.textPrimary
                  : Colors.transparent,
              width: playing || queued || selected ? 3 : 0,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('song-map-pad-${region.id}'),
            onLongPress: disabled || _rangeMode || widget.onHold == null
                ? null
                : () {
                    if (_runMade) return;
                    unawaited(HapticFeedback.selectionClick());
                    widget.onHold!(index);
                  },
            onTap: disabled
                ? null
                : () {
                    if (_runMade) return;
                    unawaited(HapticFeedback.selectionClick());
                    if (_rangeMode && widget.onRange != null) {
                      if (_rangeStart == null) {
                        setState(() => _rangeStart = index);
                      } else {
                        final start = _rangeStart! < index
                            ? _rangeStart!
                            : index;
                        final end = _rangeStart! > index ? _rangeStart! : index;
                        widget.onRange!((start, end));
                        setState(() {
                          _rangeMode = false;
                          _rangeStart = null;
                        });
                      }
                    } else if (widget.onSelect == null) {
                      widget.view.zoomIn(index);
                    } else {
                      widget.onSelect!(index);
                    }
                  },
            child: Stack(
              children: [
                if (!playing)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 6,
                    child: ColoredBox(color: accent),
                  ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: MonoPulseSpacing.sm,
                    right: MonoPulseSpacing.xs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          if (playing) ...[
                            Icon(Icons.play_arrow, color: fg, size: 20),
                            const SizedBox(width: MonoPulseSpacing.xs),
                          ],
                          Expanded(
                            child: Text(
                              songMapRegionName(region, index),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MonoPulseTypography.bodyMedium.copyWith(
                                color: fg,
                              ),
                            ),
                          ),
                          if (queued)
                            Text(
                              'next',
                              style: MonoPulseTypography.labelSmall.copyWith(
                                color: MonoPulseColors.accentOrange,
                              ),
                            ),
                        ],
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MonoPulseTypography.bodySmall.copyWith(
                          color: fg,
                        ),
                      ),
                    ],
                  ),
                ),
                if (playing)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 4,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: widget.progress.clamp(0, 1),
                        child: const ColoredBox(
                          color: MonoPulseColors.charcoal,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return Listener(
      onPointerDown: (event) {
        if (disabled || _rangeMode || widget.onRange == null) return;
        final first = _held.values.firstOrNull;
        _held[event.pointer] = index;
        if (first == null || first == index) return;
        _runMade = true;
        unawaited(HapticFeedback.selectionClick());
        widget.onRange!((math.min(first, index), math.max(first, index)));
      },
      onPointerUp: (event) => _release(event.pointer),
      onPointerCancel: (event) => _release(event.pointer),
      child: Semantics(
        key: ValueKey('region-pad-${region.id}'),
        button: true,
        selected: selected,
        child: pad,
      ),
    );
  }
}
