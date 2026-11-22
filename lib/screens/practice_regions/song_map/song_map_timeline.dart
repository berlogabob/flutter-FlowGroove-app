import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../../../models/audio_region.dart';
import '../../../models/song_lab.dart';
import '../../../services/audio/audio_note_edit.dart' show waveformLevels;
import '../../../theme/mono_pulse_theme.dart';
import '../../../widgets/audio/waveform_painter.dart';
import 'song_map_letters.dart';
import 'song_map_view.dart';

class SongMapOverview extends SongMapTimeline {
  SongMapOverview({
    required SongLabEntry entry,
    required super.view,
    required super.positionMs,
    required super.playing,
    required super.candidateBoundariesMs,
    required super.selectedIndices,
    required Widget noteTicks,
    super.waveHeight,
    super.preview,
    super.onSectionHold,
    super.onSectionTap,
    super.onSeek,
    super.focusSection,
  }) : super(
         entry: entry,
         peaks: entry.peaks,
         noteTicks: noteTicks,
         key: const ValueKey('song-map-overview'),
       );

  static const height = 96.0;
}

class SongMapTimeline extends StatefulWidget {
  const SongMapTimeline({
    required this.view,
    this.peaks = const [],
    this.waveHeight = waveformHeight,
    this.pcm,
    this.positionMs,
    this.playing = false,
    this.candidateBoundariesMs = const {},
    this.preview = false,
    this.cutLabel,
    this.boundariesMs,
    this.selectedBoundaryMs,
    this.selectedIndices = const {},
    this.onSectionHold,
    this.onSectionTap,
    this.onSeek,
    this.entry,
    this.noteTicks,
    this.focusSection,
    this.editableBoundaries = const {},
    this.onFineTune,
    this.onBoundaryTap,
    this.onBoundaryDrag,
    super.key,
  });

  static const waveformHeight = 64.0;
  static const zoomHeight = waveformHeight + MonoPulseSpacing.huge + 26 + 20;

  final SongMapView view;
  final double waveHeight;

  /// Uniformly spaced peaks for the whole recording.
  final List<int> peaks;

  /// Mono samples at the analysis rate of 22,050 Hz.
  final Int16List? pcm;
  final int? positionMs;
  final bool playing;

  /// Boundary positions and callback values are file-relative milliseconds.
  final Set<int> candidateBoundariesMs;
  final bool preview;
  final (int, String)? cutLabel;
  final Set<int>? boundariesMs;
  final int? selectedBoundaryMs;
  final Set<int> selectedIndices;
  final ValueChanged<String>? onSectionHold;
  final ValueChanged<int>? onSectionTap;
  final ValueChanged<int>? onSeek;
  final SongLabEntry? entry;
  final Widget? noteTicks;
  final int? focusSection;
  final Map<int, int> editableBoundaries;
  final ValueChanged<int>? onFineTune;
  final ValueChanged<int>? onBoundaryTap;
  final ValueChanged<(int, int)>? onBoundaryDrag;

  bool get _overview => this is SongMapOverview;

  int? get _section => _overview ? null : _zoomSection;

  int? get _zoomSection =>
      view.sectionIndex ??
      focusSection ??
      view.overviewSelection ??
      (view.sections.isEmpty ? null : 0);

  ({int startMs, int endMs}) get viewport {
    final section = _section;
    if (section == null) return (startMs: 0, endMs: view.durationMs);
    final region = view.sections[section];
    return (
      startMs: region.startMs.clamp(0, view.durationMs),
      endMs: region.endMs.clamp(0, view.durationMs),
    );
  }

  @override
  State<SongMapTimeline> createState() => _SongMapTimelineState();
}

class _SongMapTimelineState extends State<SongMapTimeline> {
  static const _partLaneHeight = MonoPulseSpacing.huge;
  static const _tipSize = MonoPulseSpacing.lg;
  static const _handleWidth = MonoPulseSpacing.xxl;

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

  int get _startMs => widget.viewport.startMs;
  int get _endMs => widget.viewport.endMs;

  double _x(int ms, double width) =>
      (ms - _startMs) / math.max(1, _endMs - _startMs) * width;

  int _ms(double x, double width) =>
      _startMs + (x / width * (_endMs - _startMs)).round();

  Widget _timeline(BuildContext context, double width) {
    final overview = widget._overview;
    final section = widget._section;
    if (!overview && section == null) return const SizedBox.shrink();
    final parts = section == null
        ? const <AudioRegion>[]
        : _view.sectionParts(section);
    final grid = _view.grid;
    final barMs = grid?.barMs ?? 0;
    final hasGrid =
        grid != null &&
        grid.beatsPerBar > 0 &&
        barMs.isFinite &&
        barMs >= grid.beatsPerBar;
    final beats = !overview && _view.level == SongMapZoom.part;
    final waveformHeight = widget.waveHeight;
    final positionMs = widget.positionMs;
    final selectedBoundary = widget.selectedBoundaryMs;
    final boundaries = {
      ...?widget.boundariesMs,
      if (widget.boundariesMs == null)
        for (final part in parts.skip(1)) part.startMs,
      ...widget.candidateBoundariesMs,
    };
    bool visible(int ms) => ms >= _startMs && ms <= _endMs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (section != null)
          Text(
            _view.sectionIndex == null
                ? '${_view.sectionLetter(section).label} · ${songMapRegionName(_view.sections[section], section)}'
                : songMapRegionName(_view.sections[section], section),
            style: MonoPulseTypography.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        GestureDetector(
          onScaleStart: overview ? null : (_) => _zoomedOut = false,
          onScaleUpdate: overview
              ? null
              : (details) {
                  if (!_zoomedOut &&
                      details.pointerCount >= 2 &&
                      details.scale > 1.15) {
                    _zoomedOut = true;
                    _view.zoomOut();
                  }
                },
          child: Stack(
            children: [
              Column(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: widget.onSeek == null
                        ? null
                        : (details) => widget.onSeek!(
                            _ms(details.localPosition.dx, width),
                          ),
                    child: RepaintBoundary(
                      child: _waveform(context.mp, width, waveformHeight),
                    ),
                  ),
                  _lane(context, width, section, parts, hasGrid ? grid : null),
                ],
              ),
              if (widget.noteTicks case final ticks?)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 10,
                  child: IgnorePointer(child: ticks),
                ),
              if (overview)
                for (final ms in widget.candidateBoundariesMs)
                  if (visible(ms))
                    _line(context, _x(ms, width), width, dashed: true),
              if (positionMs != null &&
                  visible(positionMs) &&
                  !widget.candidateBoundariesMs.contains(positionMs))
                _line(context, _x(positionMs, width), width),
              if (!overview)
                for (final ms in {
                  ...boundaries.where((ms) => ms != selectedBoundary),
                  ?selectedBoundary,
                })
                  if (ms > 0 && ms < _view.durationMs && visible(ms))
                    _boundary(
                      context,
                      ms,
                      _x(ms, width),
                      width,
                      waveformHeight,
                    ),
              if (widget.cutLabel case (final ms, final label) when visible(ms))
                Positioned(
                  left: _x(ms, width).clamp(0.0, math.max(0, width - 64)),
                  top: 0,
                  child: IgnorePointer(
                    child: Material(
                      color: context.mp.surfaceRaised,
                      borderRadius: BorderRadius.circular(
                        MonoPulseRadius.small,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(MonoPulseSpacing.xs),
                        child: Text(
                          label,
                          style: MonoPulseTypography.labelSmall,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (!overview && hasGrid) _ticks(context, grid, width),
        if (beats && hasGrid) _ticks(context, grid, width, beats: true),
        if (overview && widget.peaks.isEmpty) ...[
          Slider(
            value: _endMs == 0
                ? 0
                : ((positionMs ?? 0) / _endMs).clamp(0.0, 1.0),
            onChanged: widget.onSeek == null
                ? null
                : (value) => widget.onSeek!((value * _endMs).round()),
          ),
          Text(
            'No waveform for this take — tap or drag to seek.',
            textAlign: TextAlign.center,
            style: MonoPulseTypography.bodySmall.copyWith(
              color: context.mp.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _line(
    BuildContext context,
    double x,
    double width, {
    bool dashed = false,
  }) => Positioned(
    left: (x - 2).clamp(0.0, math.max(0, width - 4)),
    width: 4,
    top: 0,
    bottom: 0,
    child: IgnorePointer(
      child: CustomPaint(
        key: dashed ? null : const ValueKey('song-map-playhead'),
        painter: _MarkerStem(
          context.mp.textPrimary,
          thick: false,
          dashed: dashed,
        ),
      ),
    ),
  );

  Widget _waveform(MonoPulsePalette palette, double width, double height) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: palette.surfaceRaised),
          for (final (index, section) in _view.sections.indexed)
            if (section.endMs > _startMs && section.startMs < _endMs)
              Positioned(
                key: ValueKey('song-map-band-${section.id}'),
                left: _x(section.startMs, width).clamp(0.0, width),
                right: width - _x(section.endMs, width).clamp(0.0, width),
                top: 0,
                bottom: 0,
                child: ColoredBox(
                  color: _view
                      .sectionLetter(index)
                      .color
                      .withValues(alpha: 0.25),
                ),
              ),
          if (_endMs > _startMs)
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                palette.textSecondary,
                BlendMode.srcIn,
              ),
              child: CustomPaint(
                key: ValueKey(
                  widget._overview
                      ? 'song-map-overview-waveform'
                      : 'song-map-zoom-waveform',
                ),
                painter: widget._overview
                    ? _SongMapWaveformPainter(
                        entry: widget.entry,
                        peaks: widget.peaks,
                        viewport: widget.viewport,
                        durationMs: _view.durationMs,
                        dim: palette.textSecondary,
                      )
                    : _ZoomWaveformPainter(
                        peaks: widget.peaks,
                        pcm: widget.pcm,
                        viewport: widget.viewport,
                        durationMs: _view.durationMs,
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _lane(
    BuildContext context,
    double width,
    int? section,
    List<AudioRegion> parts,
    AudioGrid? grid,
  ) {
    final regions = section == null ? _view.sections : parts;
    return SizedBox(
      key: ValueKey(section == null ? 'song-map-sections' : 'song-map-parts'),
      width: width,
      height: section == null ? MonoPulseSpacing.xxxl : _partLaneHeight,
      child: Stack(
        children: [
          for (final (index, region) in regions.indexed)
            if (region.endMs > _startMs && region.startMs < _endMs)
              _block(context, region, width, index, section, grid),
        ],
      ),
    );
  }

  Widget _block(
    BuildContext context,
    AudioRegion region,
    double width,
    int index,
    int? sectionIndex,
    AudioGrid? grid,
  ) {
    final letter = _view.sectionLetter(sectionIndex ?? index);
    final isPart = sectionIndex != null;
    final selected =
        widget.selectedIndices.contains(index) ||
        (isPart ? _view.partIndex : widget._zoomSection) == index;
    final left = _x(region.startMs, width).clamp(0.0, width);
    final right = _x(region.endMs, width).clamp(0.0, width);
    if (right <= left) return const SizedBox.shrink();

    final palette = context.mp;
    final typography = Theme.of(context).textTheme;
    final positionMs = widget.positionMs;
    final playing =
        widget.playing &&
        positionMs != null &&
        positionMs >= region.startMs &&
        positionMs < region.endMs;
    final label = isPart ? songMapPartLetter(index) : letter.label;
    final name = isPart ? label : songMapRegionName(region, index);
    final nameStyle = typography.bodySmall?.copyWith(
      color: palette.textPrimary,
    );
    final bars = isPart
        ? grid?.displayBarsIn(region.startMs, region.endMs).count ?? 0
        : 0;
    final border = playing
        ? MonoPulseColors.accentOrange
        : selected
        ? palette.textPrimary
        : palette.borderStrong;
    final side = BorderSide(color: border, width: 3);
    return Positioned(
      left: left,
      width: right - left,
      top: 0,
      bottom: 0,
      child: GestureDetector(
        onTap: !isPart && widget.onSectionTap != null
            ? () => widget.onSectionTap!(index)
            : null,
        onDoubleTap:
            !isPart && _view.sectionIndex == null ||
                isPart && _view.level == SongMapZoom.section
            ? () => _view.zoomIn(index)
            : null,
        onLongPress: !isPart && widget.onSectionHold != null
            ? () => widget.onSectionHold!(region.id)
            : null,
        child: Container(
          key: ValueKey('song-map-${isPart ? 'part' : 'section'}-${region.id}'),
          padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.xxs),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              letter.color.withValues(alpha: 0.35),
              palette.surfaceRaised,
            ),
            border: widget.preview
                ? _CandidateBlockBorder(side)
                : Border.fromBorderSide(side),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: nameStyle, semanticsLabel: name),
                if (bars > 0)
                  Text(
                    bars == 1 ? '1 bar' : '$bars bars',
                    style: typography.labelSmall?.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ticks(
    BuildContext context,
    AudioGrid grid,
    double width, {
    bool beats = false,
  }) {
    final ticksPerBar = beats ? grid.beatsPerBar : 1;
    final stepMs = grid.barMs / ticksPerBar;
    final span = _endMs - _startMs;
    final spacing = span > 0 ? width * stepMs / span : 0.0;
    final palette = context.mp;
    final style = Theme.of(context).textTheme.bodySmall;
    const minLabelSpacing = MonoPulseSpacing.lg;
    var tickStride = 1;
    var labelStride = 1;
    if (beats && spacing > 0) {
      while (spacing * tickStride < MonoPulseSpacing.xxs) {
        tickStride *= 2;
      }
      labelStride = tickStride;
      while (spacing * labelStride < minLabelSpacing) {
        labelStride *= 2;
      }
    }
    final origin = grid.firstDownbeatMs;
    final first = math.max(0, ((_startMs - origin - 0.5) / stepMs).ceil());
    // Keep a downbeat near the end seam in the next section, as the pads do.
    final endBar = grid.displayBarsIn(0, _endMs).count;
    final last =
        math.min(
          ((_endMs - origin - 0.5) / stepMs).ceil(),
          endBar * ticksPerBar,
        ) -
        1;
    double x(int tick) => _x((origin + tick * stepMs).round(), width);

    return SizedBox(
      key: ValueKey(beats ? 'song-map-beats' : 'song-map-ruler'),
      width: width,
      height: beats ? MonoPulseSpacing.xxxl : 26,
      child: Stack(
        children: [
          if (spacing > 0)
            for (
              var tick = ((first + tickStride - 1) ~/ tickStride) * tickStride;
              tick <= last;
              tick += tickStride
            )
              Positioned(
                left: x(tick),
                width: (width - x(tick)).clamp(0.0, spacing * labelStride),
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
                            : 6,
                      ),
                    ),
                    const SizedBox(height: MonoPulseSpacing.xxs),
                    if (tick % labelStride == 0)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: MonoPulseSpacing.xxs,
                        ),
                        child: FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${(beats ? tick % grid.beatsPerBar : tick) + 1}',
                            style: style?.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                        ),
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
    double waveformHeight,
  ) {
    final selected = ms == widget.selectedBoundaryMs;
    final candidate = widget.candidateBoundariesMs.contains(ms);
    final onTap = widget.onBoundaryTap;
    final onDrag = widget.onBoundaryDrag;
    final parts = _view.sectionParts(widget._section!);
    final part = _view.level == SongMapZoom.section
        ? parts.indexWhere((part) => part.startMs <= ms && ms < part.endMs)
        : -1;
    final index = widget.editableBoundaries[ms];
    final center = (_dragBoundary == ms ? x + _dragDx : x).clamp(0.0, width);
    final left = (center - _handleWidth / 2)
        .clamp(0.0, math.max(0.0, width - _handleWidth))
        .toDouble();
    return Positioned(
      key: ValueKey(ms),
      left: left,
      top: 0,
      height: waveformHeight,
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
                onDrag((ms, _ms(x + _dragDx, width)));
              },
        onHorizontalDragCancel: onDrag == null
            ? null
            : () => setState(() => _dragBoundary = null),
        child: Semantics(
          label: 'Boundary at $ms ms',
          selected: selected,
          child: SizedBox(
            width: _handleWidth,
            child: Stack(
              children: [
                Positioned(
                  left: center - left - MonoPulseSpacing.xxs,
                  width: MonoPulseSpacing.xs,
                  top: 0,
                  bottom: 0,
                  child: CustomPaint(
                    painter: _MarkerStem(
                      selected
                          ? context.mp.textPrimary
                          : context.mp.borderStrong,
                      thick: selected,
                      dashed: candidate,
                    ),
                  ),
                ),
                if (index != null && widget.onFineTune != null)
                  Align(
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      key: ValueKey('marker-handle-$index'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.onFineTune!(index),
                      child: Icon(
                        Icons.drag_indicator,
                        size: _tipSize,
                        color: context.mp.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SongMapWaveformPainter extends WaveformPainter {
  _SongMapWaveformPainter({
    required this.entry,
    required this.viewport,
    required this.durationMs,
    required super.peaks,
    required super.dim,
  }) : super(trimStart: 0, trimEnd: 1, playhead: -1, markerFractions: const []);

  final SongLabEntry? entry;
  final ({int startMs, int endMs}) viewport;
  final int durationMs;

  @override
  void paint(Canvas canvas, Size size) {
    final msToPixels = size.width / (viewport.endMs - viewport.startMs);
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..translate(-viewport.startMs * msToPixels, 0);
    super.paint(canvas, Size(durationMs * msToPixels, size.height));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SongMapWaveformPainter old) =>
      super.shouldRepaint(old) ||
      viewport != old.viewport ||
      durationMs != old.durationMs;
}

class _ZoomWaveformPainter extends CustomPainter {
  const _ZoomWaveformPainter({
    required this.peaks,
    required this.pcm,
    required this.viewport,
    required this.durationMs,
  });

  final List<int> peaks;
  final Int16List? pcm;
  final ({int startMs, int endMs}) viewport;
  final int durationMs;

  @override
  void paint(Canvas canvas, Size size) {
    final span = viewport.endMs - viewport.startMs;
    if (size.isEmpty || span <= 0) return;
    final samples = pcm;
    final usePcm = samples != null && samples.isNotEmpty;
    final peaksInView = usePcm
        ? _envelope(samples, (size.width / 3).ceil())
        : peaks;
    final domain = usePcm ? span : durationMs;
    if (peaksInView.isEmpty || domain <= 0) return;

    final levels = waveformLevels(peaksInView);
    final buckets = usePcm ? levels.length : size.width.ceil();
    final step = size.width / buckets;
    final paint = Paint()
      ..strokeCap = usePcm ? StrokeCap.round : StrokeCap.butt
      // Adjacent fallback strokes share an edge. Antialiasing leaves a seam.
      ..isAntiAlias = usePcm
      ..strokeWidth = step;
    final mid = size.height / 2;
    canvas
      ..save()
      ..clipRect(Offset.zero & size);
    for (var i = 0; i < buckets; i++) {
      final x = (i + 0.5) * step;
      final level = usePcm
          ? levels[i]
          : _interpolate(levels, viewport.startMs + x / size.width * span);
      final extent = level.clamp(0.03, 1.0) * (mid - paint.strokeWidth / 2);
      canvas.drawLine(Offset(x, mid - extent), Offset(x, mid + extent), paint);
    }
    canvas.restore();
  }

  double _interpolate(List<double> levels, double ms) {
    final index = (ms / durationMs * levels.length - 0.5).clamp(
      0.0,
      levels.length - 1.0,
    );
    final left = index.floor();
    return levels[left] +
        (levels[index.ceil()] - levels[left]) * (index - left);
  }

  List<int> _envelope(Int16List samples, int buckets) {
    const samplesPerMs = 22050 / 1000;
    final stepMs = (viewport.endMs - viewport.startMs) / buckets;
    int sampleAt(int bucket) =>
        ((viewport.startMs + bucket * stepMs) * samplesPerMs).floor().clamp(
          0,
          samples.length,
        );
    final levels = List<int>.filled(buckets, 0);
    var start = sampleAt(0);
    for (var i = 0; i < buckets; i++) {
      final end = sampleAt(i + 1);
      for (; start < end; start++) {
        levels[i] = math.max(levels[i], samples[start].abs());
      }
    }
    return levels;
  }

  @override
  bool shouldRepaint(_ZoomWaveformPainter old) =>
      peaks != old.peaks ||
      pcm != old.pcm ||
      viewport != old.viewport ||
      durationMs != old.durationMs;
}

class _CandidateBlockBorder extends Border {
  const _CandidateBlockBorder(super.side) : super.fromBorderSide();

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  }) {
    final width = math.min(top.width, math.min(rect.width, rect.height) / 2);
    final path = Path()..addRect(rect.deflate(width / 2));
    final perimeter = path.computeMetrics().first;
    final paint = top.toPaint()..strokeWidth = width;
    const dash = MonoPulseSpacing.xs;
    const gap = MonoPulseSpacing.xxs;
    for (var start = 0.0; start < perimeter.length; start += dash + gap) {
      canvas.drawPath(
        perimeter.extractPath(start, math.min(start + dash, perimeter.length)),
        paint,
      );
    }
  }
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
