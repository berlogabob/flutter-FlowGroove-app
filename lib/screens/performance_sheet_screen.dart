import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/section.dart';
import '../models/song.dart';
import '../providers/wakelock_provider.dart';
import '../services/export/chordpro_export.dart';
import '../services/export/pdf_service.dart';
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
    this.song,
    this.songKey,
    this.bpm,
    this.timeTop,
    super.key,
  });

  final String title;
  final List<Section> sections;

  /// The saved song backing this sheet, when opened from one. Enables ChordPro
  /// export (needs the full song for its directives). Null for unsaved drafts.
  final Song? song;

  /// Optional song metadata rendered in the exported PDF header.
  final String? songKey;
  final int? bpm;
  final int? timeTop;

  @override
  ConsumerState<PerformanceSheetScreen> createState() =>
      _PerformanceSheetScreenState();
}

class _PerformanceSheetScreenState extends ConsumerState<PerformanceSheetScreen>
    with SingleTickerProviderStateMixin {
  int _transpose = 0;

  // ponytail: autoscroll speed is a feel heuristic (no per-line bar timing).
  // Tune the two constants on real songs; upgrade path = per-section bar counts.
  static const double _manualBase = 35; // px/sec
  static const double _bpmToPx = 0.45; // px/sec per BPM when synced
  static const double _minSpeed = 8;
  static const double _maxSpeed = 300;

  final ScrollController _scroll = ScrollController();
  late final Ticker _ticker = createTicker(_onTick);
  bool _scrolling = false;
  bool _bpmSync = false;
  double _speed = _manualBase;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    ref.read(wakelockProvider).enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scroll.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    ref.read(wakelockProvider).disable();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final next = _scroll.offset + _speed * dt;
    if (next >= max) {
      _scroll.jumpTo(max);
      _stopScroll();
    } else {
      _scroll.jumpTo(next);
    }
  }

  void _toggleScroll() {
    if (_scrolling) {
      _stopScroll();
    } else {
      _lastTick = Duration.zero;
      _ticker.start();
      setState(() => _scrolling = true);
    }
  }

  void _stopScroll() {
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
            tooltip: 'Export PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => PdfService.exportSongSheet(
              widget.title,
              widget.sections,
              transpose: _transpose,
              songKey: widget.songKey,
              bpm: widget.bpm,
              timeTop: widget.timeTop,
            ),
          ),
          if (widget.song case final song?)
            IconButton(
              tooltip: 'Export ChordPro',
              icon: const Icon(Icons.description_outlined),
              onPressed: () => shareSongChordPro(song),
            ),
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
              controller: _scroll,
              padding: const EdgeInsets.all(MonoPulseSpacing.lg),
              itemCount: withCharts.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: MonoPulseSpacing.xl),
              itemBuilder: (context, i) =>
                  _SectionBlock(section: withCharts[i], transpose: _transpose),
            ),
      bottomNavigationBar: withCharts.isEmpty
          ? null
          : _AutoScrollBar(
              scrolling: _scrolling,
              bpmSync: _bpmSync,
              speed: _speed,
              onToggle: _toggleScroll,
              onSlower: () => _nudgeSpeed(0.8),
              onFaster: () => _nudgeSpeed(1.25),
              onToggleBpm: _toggleBpmSync,
            ),
    );
  }
}

/// Bottom transport for hands-free scrolling: play/pause, ± speed, and a
/// Manual ⇄ BPM mode toggle.
class _AutoScrollBar extends StatelessWidget {
  const _AutoScrollBar({
    required this.scrolling,
    required this.bpmSync,
    required this.speed,
    required this.onToggle,
    required this.onSlower,
    required this.onFaster,
    required this.onToggleBpm,
  });

  final bool scrolling;
  final bool bpmSync;
  final double speed;
  final VoidCallback onToggle;
  final VoidCallback onSlower;
  final VoidCallback onFaster;
  final VoidCallback onToggleBpm;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MonoPulseSpacing.md,
          vertical: MonoPulseSpacing.sm,
        ),
        child: Row(
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
