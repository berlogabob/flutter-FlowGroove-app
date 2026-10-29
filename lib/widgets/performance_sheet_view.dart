import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/section.dart';
import '../theme/mono_pulse_theme.dart';
import '../utils/chordpro.dart';
import 'chord_chart_view.dart';

/// The performance-sheet body: chords-over-lyrics rows with live ± transpose
/// and the auto-scroll transport. Extracted from [PerformanceSheetScreen] so
/// the Song Page's Sheet tab and the full-screen stage view render the exact
/// same thing; hosts own wakelock/immersive/system chrome.
class PerformanceSheetView extends StatefulWidget {
  const PerformanceSheetView({
    required this.sections,
    this.bpm,
    this.revision = 0,
    this.initialTranspose = 0,
    this.onTransposeChanged,
    this.emptyState,
    super.key,
  });

  final List<Section> sections;
  final int? bpm;

  /// Bump when [sections] were mutated in place so the pre-parsed rows are
  /// rebuilt (the list identity doesn't change on in-place edits).
  final int revision;

  final int initialTranspose;
  final ValueChanged<int>? onTransposeChanged;

  /// Shown when no section has chart/notes content.
  final Widget? emptyState;

  @override
  PerformanceSheetViewState createState() => PerformanceSheetViewState();
}

class PerformanceSheetViewState extends State<PerformanceSheetView>
    with SingleTickerProviderStateMixin {
  late int _transpose = widget.initialTranspose;

  // ponytail: autoscroll speed is a feel heuristic (no per-line bar timing).
  // Tune the two constants on real songs; upgrade path = per-section bar counts.
  static const double _manualBase = 35; // px/sec
  static const double _bpmToPx = 0.45; // px/sec per BPM when synced
  static const double _minSpeed = 8;
  static const double _maxSpeed = 300;

  final ScrollController _scroll = ScrollController();
  // Created in initState (not lazily) so the TickerMode lookup happens while
  // mounted — a lazy `= createTicker(...)` would first run inside dispose() when
  // autoscroll was never started, looking up a deactivated ancestor (#96).
  late final Ticker _ticker;
  bool _scrolling = false;
  bool _bpmSync = false;
  double _speed = _manualBase;
  Duration _lastTick = Duration.zero;

  // Flat, pre-parsed rows (headers + chord lines). Built once and only rebuilt
  // when transpose/revision changes, so scroll-time item builds do zero
  // parsing. One ListView item per LINE (not per section) keeps each frame's
  // build cheap (#96).
  late List<_Row> _rows;

  @override
  void initState() {
    super.initState();
    _recomputeRows();
    _ticker = createTicker(_onTick);
  }

  @override
  void didUpdateWidget(PerformanceSheetView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision ||
        !identical(oldWidget.sections, widget.sections)) {
      _recomputeRows();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _recomputeRows() {
    final rows = <_Row>[];
    for (final s in widget.sections) {
      final chart = s.chordChart?.trim() ?? '';
      final notes = s.notes.trim();
      if (chart.isEmpty && notes.isEmpty) continue;
      rows.add(_Row.header(s.name));
      if (chart.isNotEmpty) {
        for (final line in transposeChordChart(chart, _transpose).split('\n')) {
          rows.add(_Row.line(parseChordProLine(line)));
        }
      } else {
        rows.add(_Row.notes(notes));
      }
    }
    _rows = rows;
  }

  void _changeTranspose(int delta) {
    setState(() {
      _transpose += delta;
      _recomputeRows();
    });
    widget.onTransposeChanged?.call(_transpose);
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final next = _scroll.offset + _speed * dt;
    if (next >= max) {
      _scroll.jumpTo(max);
      stopScroll();
    } else {
      _scroll.jumpTo(next);
    }
  }

  void _toggleScroll() {
    if (_scrolling) {
      stopScroll();
    } else {
      _lastTick = Duration.zero;
      _ticker.start();
      setState(() => _scrolling = true);
    }
  }

  /// Public so a host can halt the ticker before popping its route (#96).
  void stopScroll() {
    _ticker.stop();
    if (mounted) setState(() => _scrolling = false);
  }

  void _nudgeSpeed(double factor) {
    setState(() {
      _bpmSync = false;
      _speed = (_speed * factor).clamp(_minSpeed, _maxSpeed);
    });
  }

  void _toggleBpmSync() {
    setState(() {
      _bpmSync = !_bpmSync;
      _speed = _bpmSync
          ? ((widget.bpm ?? 90) * _bpmToPx).clamp(_minSpeed, _maxSpeed)
          : _manualBase;
    });
  }

  String get _transposeLabel {
    if (_transpose == 0) return 'Original';
    return _transpose > 0 ? '+$_transpose' : '$_transpose';
  }

  @override
  Widget build(BuildContext context) {
    final lyric =
        Theme.of(context).textTheme.headlineSmall ?? const TextStyle();
    final chordStyle = lyric.copyWith(
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.primary,
    );

    if (_rows.isEmpty) {
      return widget.emptyState ?? const SizedBox.shrink();
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(MonoPulseSpacing.lg),
            itemCount: _rows.length,
            itemBuilder: (context, i) => _rows[i].build(
              context,
              first: i == 0,
              lyric: lyric,
              chord: chordStyle,
            ),
          ),
        ),
        _AutoScrollBar(
          scrolling: _scrolling,
          bpmSync: _bpmSync,
          speed: _speed,
          transposeLabel: _transposeLabel,
          onToggle: _toggleScroll,
          onSlower: () => _nudgeSpeed(0.8),
          onFaster: () => _nudgeSpeed(1.25),
          onToggleBpm: _toggleBpmSync,
          onTransposeDown: () => _changeTranspose(-1),
          onTransposeUp: () => _changeTranspose(1),
        ),
      ],
    );
  }
}

/// Bottom transport for hands-free scrolling: play/pause, ± speed, a
/// Manual ⇄ BPM mode toggle, and live ± transpose.
class _AutoScrollBar extends StatelessWidget {
  const _AutoScrollBar({
    required this.scrolling,
    required this.bpmSync,
    required this.speed,
    required this.transposeLabel,
    required this.onToggle,
    required this.onSlower,
    required this.onFaster,
    required this.onToggleBpm,
    required this.onTransposeDown,
    required this.onTransposeUp,
  });

  final bool scrolling;
  final bool bpmSync;
  final double speed;
  final String transposeLabel;
  final VoidCallback onToggle;
  final VoidCallback onSlower;
  final VoidCallback onFaster;
  final VoidCallback onToggleBpm;
  final VoidCallback onTransposeDown;
  final VoidCallback onTransposeUp;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MonoPulseSpacing.md,
          vertical: MonoPulseSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.music_note,
                  size: MonoPulseIcons.sizeMedium,
                  color: context.mp.textSecondary,
                ),
                const SizedBox(width: MonoPulseSpacing.sm),
                const Text('Transpose', style: MonoPulseTypography.labelLarge),
                const Spacer(),
                IconButton(
                  onPressed: onTransposeDown,
                  icon: const Icon(Icons.remove),
                  tooltip: 'Transpose down',
                ),
                Text(transposeLabel, style: MonoPulseTypography.labelLarge),
                IconButton(
                  onPressed: onTransposeUp,
                  icon: const Icon(Icons.add),
                  tooltip: 'Transpose up',
                ),
              ],
            ),
            Row(
              children: [
                IconButton.filled(
                  onPressed: onToggle,
                  icon: Icon(scrolling ? Icons.pause : Icons.play_arrow),
                  tooltip: scrolling ? 'Pause scroll' : 'Auto-scroll',
                ),
                const SizedBox(width: MonoPulseSpacing.sm),
                IconButton(
                  onPressed: onSlower,
                  icon: const Icon(Icons.remove),
                  tooltip: 'Slower',
                ),
                Text(
                  '${speed.round()} px/s',
                  style: MonoPulseTypography.labelLarge,
                ),
                IconButton(
                  onPressed: onFaster,
                  icon: const Icon(Icons.add),
                  tooltip: 'Faster',
                ),
                const Spacer(),
                ChoiceChip(
                  label: Text(bpmSync ? 'BPM' : 'Manual'),
                  selected: bpmSync,
                  onSelected: (_) => onToggleBpm(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One flat list row: a section header, a pre-parsed chord line, or a plain
/// notes block. Parsing happens once at build-of-rows time (not per frame), so
/// each ListView item is cheap to render while scrolling (#96).
class _Row {
  const _Row.header(this.name) : segments = null, notes = null;
  const _Row.line(this.segments) : name = null, notes = null;
  const _Row.notes(this.notes) : name = null, segments = null;

  final String? name;
  final List<ChordSegment>? segments;
  final String? notes;

  Widget build(
    BuildContext context, {
    required bool first,
    required TextStyle lyric,
    required TextStyle chord,
  }) {
    if (name != null) {
      return Padding(
        padding: EdgeInsets.only(
          top: first ? 0 : MonoPulseSpacing.xl,
          bottom: MonoPulseSpacing.sm,
        ),
        child: Text(
          name!,
          style: MonoPulseTypography.titleMedium.copyWith(
            color: MonoPulseColors.accentOrange,
          ),
        ),
      );
    }
    if (notes != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(notes!, style: Theme.of(context).textTheme.titleLarge),
      );
    }
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ChordLineView(segments: segments!, lyric: lyric, chord: chord),
      ),
    );
  }
}
