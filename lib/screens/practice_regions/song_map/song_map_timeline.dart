import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart';
import 'package:material_ui/material_ui.dart';

import '../../../models/audio_region.dart';
import '../../../models/section.dart';
import '../../../theme/mono_pulse_theme.dart';
import '../../../widgets/audio/waveform_painter.dart';
import 'song_map_view.dart';

class SongMapTimeline extends StatefulWidget {
  const SongMapTimeline({
    required this.view,
    this.peaks = const [],
    this.positionMs,
    this.playing = false,
    this.candidateBoundariesMs = const {},
    this.boundariesMs,
    this.selectedBoundaryMs,
    this.selectedIndices = const {},
    this.onSectionHold,
    this.onBoundaryTap,
    this.onBoundaryDrag,
    super.key,
  });

  final SongMapView view;

  /// Uniformly spaced peaks for the whole recording.
  final List<int> peaks;
  final int? positionMs;
  final bool playing;

  /// Boundary positions and callback values are file-relative milliseconds.
  final Set<int> candidateBoundariesMs;
  final Set<int>? boundariesMs;
  final int? selectedBoundaryMs;
  final Set<int> selectedIndices;
  final ValueChanged<String>? onSectionHold;
  final ValueChanged<int>? onBoundaryTap;
  final ValueChanged<(int, int)>? onBoundaryDrag;

  @override
  State<SongMapTimeline> createState() => _SongMapTimelineState();
}

class _SongMapTimelineState extends State<SongMapTimeline> {
  static const _laneHeight = MonoPulseSpacing.massive;
  static const _tipSize = MonoPulseSpacing.lg;
  static const _handleWidth = MonoPulseSpacing.xxl;
  static final _occurrenceSuffix = RegExp(r'\s+\d+$');

  bool _zoomedOut = false;
  double _dragDx = 0;
  int? _dragBoundary;

  SongMapView get _view => widget.view;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _view,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) =>
          _timeline(context, constraints.maxWidth),
    ),
  );

  Widget _timeline(BuildContext context, double width) {
    final palette = context.mp;
    final level = _view.level;
    final atSong = level == SongMapZoom.song;
    final atPart = level == SongMapZoom.part;
    final children = _view.children();
    final parts = atSong ? const <AudioRegion>[] : children;
    // At deeper levels the view exposes the focused section’s parts.
    final sections = atSong
        ? children
        : [
            if (parts.isNotEmpty)
              parts.first.copyWith(
                name: parts.first.section?.isNotEmpty ?? false
                    ? parts.first.section
                    : parts.first.name,
                endMs: parts.last.endMs,
              ),
          ];
    final grid = _view.grid;
    final barMs = grid?.barMs ?? 0;
    final hasGrid =
        grid != null &&
        grid.beatsPerBar > 0 &&
        barMs.isFinite &&
        barMs >= grid.beatsPerBar;
    final waveformHeight = atSong ? 92.0 : 72.0;
    const waveformTop = _laneHeight + MonoPulseSpacing.sm;
    final positionMs = widget.positionMs;
    final selectedBoundary = widget.selectedBoundaryMs;
    final boundaries = {
      ...?widget.boundariesMs,
      if (widget.boundariesMs == null && !atSong)
        for (final part in parts) ...[part.startMs, part.endMs],
      ...widget.candidateBoundariesMs,
    };
    double x(int ms) => _view.msToX(ms, width);
    bool visible(int ms) => ms >= _view.startMs && ms <= _view.endMs;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      onScaleStart: (_) => _zoomedOut = false,
      onScaleUpdate: (details) {
        if (!_zoomedOut && details.pointerCount >= 2 && details.scale > 1.15) {
          _zoomedOut = true;
          _view.zoomOut();
        }
      },
      child: SizedBox(
        width: width,
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _lane(
                  context,
                  sections,
                  width,
                  onZoom: atSong ? _view.zoomIn : null,
                  selectedIndices: atSong ? widget.selectedIndices : const {0},
                ),
                const SizedBox(height: MonoPulseSpacing.sm),
                _waveform(palette, width, waveformHeight),
                if (hasGrid) _ticks(context, grid, width),
                if (!atSong)
                  _lane(
                    context,
                    parts,
                    width,
                    isParts: true,
                    barMs: hasGrid ? barMs : null,
                    onZoom: atPart ? null : _view.zoomIn,
                    selectedIndices: widget.selectedIndices,
                  ),
                if (atPart && hasGrid)
                  _ticks(context, grid, width, beats: true),
              ],
            ),
            if (positionMs != null && visible(positionMs))
              Positioned(
                left: x(positionMs) - _handleWidth / 2,
                top: waveformTop - _tipSize / 2,
                height: waveformHeight + _tipSize,
                child: const IgnorePointer(
                  child: _TimelineMarker(
                    icon: Icons.arrow_drop_down,
                    color: MonoPulseColors.accentOrange,
                  ),
                ),
              ),
            for (final ms in boundaries)
              if (ms != selectedBoundary &&
                  ms > 0 &&
                  ms < _view.durationMs &&
                  visible(ms))
                _boundary(
                  context,
                  ms,
                  x(ms),
                  width,
                  waveformTop,
                  waveformHeight,
                ),
            if (selectedBoundary != null && visible(selectedBoundary))
              _boundary(
                context,
                selectedBoundary,
                x(selectedBoundary),
                width,
                waveformTop,
                waveformHeight,
              ),
          ],
        ),
      ),
    );
  }

  Widget _waveform(MonoPulsePalette palette, double width, double height) {
    final span = _view.endMs - _view.startMs;
    final fullWidth = span > 0 ? width * _view.durationMs / span : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(MonoPulseRadius.small),
      child: ColoredBox(
        color: palette.surfaceRaised,
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              if (fullWidth > 0 && widget.peaks.isNotEmpty)
                Positioned(
                  left: _view.msToX(0, width),
                  width: fullWidth,
                  top: 0,
                  bottom: 0,
                  child: CustomPaint(
                    painter: WaveformPainter(
                      peaks: widget.peaks,
                      trimStart: 0,
                      trimEnd: 1,
                      playhead: -1,
                      markerFractions: const [],
                      dim: palette.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lane(
    BuildContext context,
    List<AudioRegion> regions,
    double width, {
    bool isParts = false,
    double? barMs,
    ValueChanged<int>? onZoom,
    Set<int> selectedIndices = const {},
  }) {
    return SizedBox(
      key: ValueKey(isParts ? 'song-map-parts' : 'song-map-sections'),
      width: width,
      height: _laneHeight,
      child: Stack(
        children: [
          for (final (index, region) in regions.indexed)
            if (region.endMs > _view.startMs && region.startMs < _view.endMs)
              _block(
                context,
                region,
                width,
                isPart: isParts,
                selected:
                    selectedIndices.contains(index) ||
                    (isParts && _view.partIndex == index),
                barMs: barMs,
                onZoom: onZoom == null ? null : () => onZoom(index),
              ),
        ],
      ),
    );
  }

  Widget _block(
    BuildContext context,
    AudioRegion region,
    double width, {
    required bool isPart,
    required bool selected,
    required double? barMs,
    required VoidCallback? onZoom,
  }) {
    final left = _view.msToX(region.startMs, width).clamp(0.0, width);
    final right = _view.msToX(region.endMs, width).clamp(0.0, width);
    if (right <= left) return const SizedBox.shrink();

    final palette = context.mp;
    final typography = Theme.of(context).textTheme;
    final section = region.section;
    final positionMs = widget.positionMs;
    final playing =
        widget.playing &&
        positionMs != null &&
        positionMs >= region.startMs &&
        positionMs < region.endMs;
    final base = _baseName(
      isPart && section != null && section.isNotEmpty ? section : region.name,
    );
    final color = _sectionColor(base);
    final tint = Color.alphaBlend(
      color.withValues(alpha: 0.2),
      palette.surface,
    );
    final sectionName = section?.isNotEmpty == true
        ? section!
        : songMapRegionName(region, _view.children().indexOf(region));
    final nameStyle = typography.bodySmall?.copyWith(
      color: palette.textPrimary,
    );
    final fullNameFits =
        nameStyle != null &&
        _fits(sectionName, nameStyle, right - left - MonoPulseSpacing.xxs * 2);
    final label = isPart
        ? section != null && region.name.startsWith('$section ')
              ? region.name.substring(section.length + 1)
              : region.name
        : fullNameFits
        ? sectionName
        : songMapRegionLetter(_view.children().indexOf(region));
    final bars = barMs == null ? 0 : (region.lengthMs / barMs).round();
    final border = playing
        ? MonoPulseColors.accentOrange
        : selected
        ? palette.textPrimary
        : palette.borderStrong;
    return Positioned(
      left: left,
      width: right - left,
      top: 0,
      bottom: 0,
      child: GestureDetector(
        onDoubleTap: onZoom,
        onLongPress: !isPart && section != null && widget.onSectionHold != null
            ? () => widget.onSectionHold!(section)
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.xxs),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: playing
                ? Color.alphaBlend(
                    MonoPulseColors.charcoal.withValues(alpha: 0.12),
                    tint,
                  )
                : tint,
            borderRadius: BorderRadius.circular(MonoPulseRadius.button),
            border: Border.all(
              color: border,
              width: selected || playing ? 3 : 1,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: nameStyle),
                if (bars > 0)
                  Text(
                    bars == 1 ? '1 bar' : '$bars bars',
                    style: typography.labelSmall?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static bool _fits(String text, TextStyle style, double width) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);
    return painter.width <= width;
  }

  Widget _ticks(
    BuildContext context,
    AudioGrid grid,
    double width, {
    bool beats = false,
  }) {
    final stepMs = beats ? grid.barMs / grid.beatsPerBar : grid.barMs;
    final span = _view.endMs - _view.startMs;
    final spacing = span > 0 ? width * stepMs / span : 0.0;
    final palette = context.mp;
    final style = Theme.of(context).textTheme.bodySmall;
    final overview = _view.level == SongMapZoom.song;
    final minLabelSpacing = beats
        ? MonoPulseSpacing.lg
        : overview
        ? MonoPulseSpacing.xxxl
        : MonoPulseSpacing.xl;
    var tickStride = 1;
    var labelStride = 1;
    if (spacing > 0) {
      while (spacing * tickStride < MonoPulseSpacing.xxs) {
        tickStride *= 2;
      }
      labelStride = tickStride;
      while (spacing * labelStride < minLabelSpacing) {
        labelStride *= 2;
      }
    }
    if (overview) tickStride = labelStride;
    final first = math.max(
      0,
      ((_view.startMs - grid.offsetMs) / stepMs).ceil(),
    );
    final last = ((_view.endMs - grid.offsetMs) / stepMs).floor();

    return SizedBox(
      key: ValueKey(beats ? 'song-map-beats' : 'song-map-ruler'),
      width: width,
      height: beats ? MonoPulseSpacing.xxxl : MonoPulseSpacing.xxl,
      child: Stack(
        children: [
          if (spacing > 0)
            for (
              var tick = ((first + tickStride - 1) ~/ tickStride) * tickStride;
              tick <= last;
              tick += tickStride
            )
              Positioned(
                left: _view.msToX(
                  grid.msOfBar(beats ? tick / grid.beatsPerBar : tick),
                  width,
                ),
                top: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ColoredBox(
                      color: palette.borderStrong,
                      child: SizedBox(
                        width: 1,
                        height: beats && tick % grid.beatsPerBar == 0
                            ? MonoPulseSpacing.md
                            : MonoPulseSpacing.xs,
                      ),
                    ),
                    if (tick % labelStride == 0)
                      Text(
                        '${(beats ? tick % grid.beatsPerBar : tick) + 1}',
                        style: style?.copyWith(color: palette.textSecondary),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _boundary(
    BuildContext context,
    int ms,
    double x,
    double width,
    double waveformTop,
    double waveformHeight,
  ) {
    final selected = ms == widget.selectedBoundaryMs;
    final candidate = widget.candidateBoundariesMs.contains(ms);
    final onTap = widget.onBoundaryTap;
    final onDrag = widget.onBoundaryDrag;
    final parts = _view.children();
    final part = _view.level == SongMapZoom.section
        ? parts.indexWhere((part) => part.startMs <= ms && ms < part.endMs)
        : -1;
    return Positioned(
      key: ValueKey(ms),
      left:
          (_dragBoundary == ms ? x + _dragDx : x).clamp(0.0, width) -
          _handleWidth / 2,
      top: waveformTop - _tipSize / 2,
      height: waveformHeight + _tipSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onTap: onTap == null ? null : () => onTap(ms),
        onDoubleTap: part < 0 ? null : () => _view.zoomIn(part),
        onHorizontalDragStart: onDrag == null
            ? null
            : (_) => setState(() {
                _dragBoundary = ms;
                _dragDx = 0;
              }),
        onHorizontalDragUpdate: onDrag == null
            ? null
            : (details) => setState(() => _dragDx += details.delta.dx),
        onHorizontalDragEnd: onDrag == null
            ? null
            : (_) {
                setState(() => _dragBoundary = null);
                onDrag((ms, _view.xToMs(x + _dragDx, width)));
              },
        onHorizontalDragCancel: onDrag == null
            ? null
            : () => setState(() => _dragBoundary = null),
        child: Semantics(
          label: 'Boundary at $ms ms',
          selected: selected,
          child: _TimelineMarker(
            icon: Icons.drag_indicator,
            color: selected ? context.mp.textPrimary : context.mp.borderStrong,
            thick: selected,
            dashed: candidate,
          ),
        ),
      ),
    );
  }

  static String _baseName(String name) =>
      name.trim().toLowerCase().replaceFirst(_occurrenceSuffix, '');

  static Color _sectionColor(String base) {
    const colors = MonoPulseColors.sectionColors;
    final template = Section.templates.indexWhere(
      (name) => name.toLowerCase() == base,
    );
    if (template >= 0) return colors[template];
    final hash = base.codeUnits.fold(
      0,
      (hash, unit) => (hash * 31 + unit) & 0x7fffffff,
    );
    return colors[hash % colors.length];
  }
}

class _TimelineMarker extends StatelessWidget {
  const _TimelineMarker({
    required this.icon,
    required this.color,
    this.thick = false,
    this.dashed = false,
  });

  final IconData icon;
  final Color color;
  final bool thick;
  final bool dashed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _SongMapTimelineState._handleWidth,
    child: Column(
      children: [
        Icon(icon, size: _SongMapTimelineState._tipSize, color: color),
        Expanded(
          child: CustomPaint(
            size: const Size.fromWidth(MonoPulseSpacing.xs),
            painter: _MarkerStem(color, thick: thick, dashed: dashed),
          ),
        ),
      ],
    ),
  );
}

class _MarkerStem extends CustomPainter {
  const _MarkerStem(this.color, {required this.thick, required this.dashed});

  final Color color;
  final bool thick;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thick ? 4 : 2;
    final x = size.width / 2;
    if (dashed) {
      for (var y = 0.0; y < size.height; y += 6) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x, math.min(y + 3, size.height)),
          paint,
        );
      }
    } else {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_MarkerStem oldDelegate) =>
      color != oldDelegate.color ||
      thick != oldDelegate.thick ||
      dashed != oldDelegate.dashed;
}
