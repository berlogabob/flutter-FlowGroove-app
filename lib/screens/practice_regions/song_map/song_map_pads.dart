import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../models/audio_region.dart';
import '../../../theme/mono_pulse_theme.dart';
import 'song_map_letters.dart';
import 'song_map_view.dart';

/// Practice pads for the current level of a [SongMapView].
class SongMapPads extends StatefulWidget {
  const SongMapPads({
    required this.view,
    this.showChop = false,
    this.chopLit = false,
    this.onChop,
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
  static double heightForRows(BuildContext context, int rows, double width) =>
      MonoPulseSpacing.massive +
      (_compactHeader(context, width) ? 0 : MonoPulseSpacing.xxl) +
      (width < 300 ? MonoPulseSpacing.massive + MonoPulseSpacing.xs : 0) +
      rows * padHeight +
      (rows + 1) * MonoPulseSpacing.sm;

  static int columnsForWidth(double width) => width < 600 ? 2 : 4;
  static const _backWidth = 68.0;
  static bool _compactHeader(BuildContext context, double width) =>
      width >= 340 && MediaQuery.sizeOf(context).height < 640;

  final SongMapView view;
  final bool showChop;
  final bool chopLit;
  final ValueChanged<bool>? onChop;
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
  bool _shift = false;
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

  Widget _key(
    BuildContext context,
    String label,
    VoidCallback? onPressed, {
    bool? selected,
  }) {
    final palette = context.mp;
    final lit = selected == true;
    final width = switch (label) {
      'Shift' => 56.0,
      'Chop' => 80.0,
      _ => SongMapPads._backWidth,
    };
    return Semantics(
      selected: selected,
      child: OutlinedButton(
        key: ValueKey('song-map-key-$label'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          fixedSize: Size(width, 48),
          padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.xs),
          visualDensity: VisualDensity.standard,
          backgroundColor: lit
              ? MonoPulseColors.accentOrange
              : palette.surfaceRaised,
          disabledBackgroundColor: palette.surfaceRaised,
          foregroundColor: lit ? MonoPulseColors.charcoal : palette.textPrimary,
          side: BorderSide(
            color: lit ? MonoPulseColors.accentOrange : palette.borderStrong,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
          ),
          textStyle: MonoPulseTypography.labelMedium,
        ),
        onPressed: onPressed,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: MonoPulseSpacing.xs,
            children: [
              if (label == 'Chop')
                SizedBox(
                  width: 16,
                  height: 16,
                  child: lit ? const Icon(Icons.content_cut, size: 16) : null,
                ),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.view,
    builder: (context, _) {
      final children = widget.view.children();
      final section = widget.view.sectionIndex;
      return LayoutBuilder(
        builder: (context, constraints) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MonoPulseSpacing.sm,
              ),
              child: LayoutBuilder(
                builder: (context, _) {
                  final name = Text(
                    section == null
                        ? 'Sections'
                        : '${widget.view.sectionLetter(section).label} · ${songMapRegionName(widget.view.sections[section], section)}',
                    style: MonoPulseTypography.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                  final keys = [
                    if (section != null)
                      Tooltip(
                        message: 'Zoom out',
                        child: _key(context, '‹ Song', widget.view.zoomToSong),
                      )
                    else
                      const SizedBox(width: SongMapPads._backWidth, height: 48),
                    Tooltip(
                      message: 'Shift',
                      excludeFromSemantics: true,
                      child: _key(
                        context,
                        'Shift',
                        () => setState(() => _shift = !_shift),
                        selected: _shift,
                      ),
                    ),
                    if (widget.showChop)
                      _key(
                        context,
                        'Chop',
                        widget.onChop == null
                            ? null
                            : () {
                                final remove = _shift;
                                if (remove) setState(() => _shift = false);
                                widget.onChop!(remove);
                              },
                        selected: widget.chopLit,
                      ),
                    _key(
                      context,
                      'Range',
                      widget.onRange == null
                          ? null
                          : () => setState(() {
                              _rangeMode = !_rangeMode;
                              _rangeStart = null;
                            }),
                      selected: _rangeMode,
                    ),
                  ];
                  if (SongMapPads._compactHeader(
                    context,
                    constraints.maxWidth,
                  )) {
                    return Row(
                      spacing: MonoPulseSpacing.xs,
                      children: [
                        Expanded(child: name),
                        ...keys,
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      name,
                      Wrap(
                        spacing: MonoPulseSpacing.xs,
                        runSpacing: MonoPulseSpacing.xs,
                        children: keys,
                      ),
                    ],
                  );
                },
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                primary: false,
                child: _grid(context, children, constraints.maxWidth),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _grid(BuildContext context, List<AudioRegion> children, double width) {
    final columns = SongMapPads.columnsForWidth(width);
    const gap = MonoPulseSpacing.sm;
    const inset = MonoPulseSpacing.lg;
    final padWidth = (width - 2 * inset - (columns - 1) * gap) / columns;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: inset, vertical: gap),
      child: Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final (index, region) in children.indexed)
            _pad(context, region, index, padWidth),
        ],
      ),
    );
  }

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
    final section = widget.view.sectionIndex;
    final letter = widget.view.sectionLetter(section ?? index);
    final label = section == null ? letter.label : songMapPartLetter(index);
    final grid = widget.view.grid;
    final displayBars = grid?.displayBarsIn(region.startMs, region.endMs);
    final bars = displayBars?.count ?? 0;
    var name = songMapRegionName(region, index);
    if (section != null && displayBars != null && bars > 0) {
      final first = displayBars.first;
      name = 'Bars $first-${first + bars - 1}';
    }
    final subtitle = region.skip
        ? 'Skipped'
        : region.lengthMs < (grid?.barMs ?? 2000)
        ? '⚠ ${(region.lengthMs / 1000).toStringAsFixed(1)} s'
        : bars > 0
        ? '$bars bars'
        : '${(region.lengthMs / 1000).round()} s';
    final bg = playing ? MonoPulseColors.accentOrange : context.mp.surface;
    final fg = playing ? MonoPulseColors.charcoal : context.mp.textPrimary;
    final shortName = name.characters.length <= 10;
    final nameText = Text(
      name,
      maxLines: shortName ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: MonoPulseTypography.labelLarge.copyWith(color: fg),
    );
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
              width: 3,
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
                    if (_shift && section == null) {
                      setState(() => _shift = false);
                      widget.view.zoomIn(index);
                    } else if (_rangeMode && widget.onRange != null) {
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
                    child: ColoredBox(color: letter.color),
                  ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: MonoPulseSpacing.sm,
                    right: MonoPulseSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: DecoratedBox(
                          key: ValueKey('song-map-pad-badge-${region.id}'),
                          decoration: BoxDecoration(
                            color: letter.color,
                            borderRadius: BorderRadius.circular(
                              MonoPulseRadius.small,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: MonoPulseSpacing.xs,
                            ),
                            child: Text(
                              label,
                              style: MonoPulseTypography.labelSmall.copyWith(
                                color: letter.textColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: MonoPulseSpacing.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (shortName)
                              nameText
                            else
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: nameText,
                              ),
                            Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: playing
                                      ? Icon(
                                          Icons.play_arrow,
                                          color: fg,
                                          size: 16,
                                        )
                                      : null,
                                ),
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      subtitle,
                                      maxLines: 1,
                                      style: MonoPulseTypography.bodySmall
                                          .copyWith(color: fg),
                                    ),
                                  ),
                                ),
                                Visibility(
                                  visible: queued,
                                  maintainState: true,
                                  maintainAnimation: true,
                                  maintainSize: true,
                                  child: Text(
                                    'next',
                                    style: MonoPulseTypography.labelSmall
                                        .copyWith(
                                          color: MonoPulseColors.accentOrange,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ],
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
        if (disabled || _shift || _rangeMode || widget.onRange == null) return;
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
