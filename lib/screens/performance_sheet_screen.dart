import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/section.dart';
import '../models/song.dart';
import '../providers/wakelock_provider.dart';
import '../services/export/chordpro_export.dart';
import '../services/export/pdf_service.dart';
import '../services/export/setlist_export_sheet.dart';
import '../services/wakelock_controller.dart';
import '../theme/mono_pulse_theme.dart';
import '../utils/chordpro.dart';
import '../utils/snackbar.dart';
import '../widgets/app_menu_sheet.dart';
import '../widgets/bottom_nav_or_action_bar.dart';
import '../widgets/chord_chart_view.dart';
import 'songs/chordpro_sync_controller.dart';
import 'songs/components/import_lyrics_dialog.dart';
import 'songs/song_editor_screen.dart';

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
  // Created in initState (not lazily) so the TickerMode lookup happens while
  // mounted — a lazy `= createTicker(...)` would first run inside dispose() when
  // autoscroll was never started, looking up a deactivated ancestor (#96).
  late final Ticker _ticker;
  // Captured in initState: `ref` is unsafe in dispose() (throws StateError),
  // so hold the controller directly to release the wakelock on close (#96).
  late final WakelockController _wakelock;
  bool _scrolling = false;
  bool _bpmSync = false;
  double _speed = _manualBase;
  Duration _lastTick = Duration.zero;

  // Flat, pre-parsed rows (headers + chord lines). Built once and only rebuilt
  // when transpose changes, so scroll-time item builds do zero parsing. Feeding
  // one ListView item per LINE (not per section) keeps each frame's build cheap
  // — a dense section no longer lays out hundreds of Texts in a single frame,
  // which is what triggered the ANR (#96).
  late List<_Row> _rows;

  @override
  void initState() {
    super.initState();
    _recomputeRows();
    _ticker = createTicker(_onTick);
    _wakelock = ref.read(wakelockProvider)..enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scroll.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _wakelock.disable();
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

  Future<void> _exportPdf() async {
    final layout = await pickSongSheetPdfLayout(context);
    if (layout == null) return;
    try {
      await PdfService.exportSongSheet(
        widget.title,
        widget.sections,
        transpose: _transpose,
        songKey: widget.songKey,
        bpm: widget.bpm,
        timeTop: widget.timeTop,
        fitOnePage: layout == SetlistPdfLayout.compact,
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, 'PDF export failed: $e');
    }
  }

  Future<void> _exportChordPro(Song song) async {
    try {
      await shareSongChordPro(song);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, 'ChordPro export failed: $e');
    }
  }

  // Stop autoscroll BEFORE the pop so the ticker isn't firing jumpTo every frame
  // through the route's exit transition, and pop via the Navigator this screen
  // was pushed onto (`Navigator.push`) instead of the shared bar's go_router
  // `context.pop()` — popping an imperatively-pushed route through go_router is
  // the freeze suspect (#96).
  void _handleBack() {
    _stopScroll();
    Navigator.of(context).pop();
  }

  /// Opens the full-screen Song editor (live map ⇄ ChordPro sync) seeded from
  /// the current performance sheet data.
  Future<void> _openSongEditor() async {
    final result = await Navigator.of(context).push<ImportedSong>(
      MaterialPageRoute<ImportedSong>(
        builder: (_) => SongEditorScreen(
          title: widget.title,
          sections: widget.sections,
          artist: widget.song?.artist,
          songKey: widget.songKey,
          bpm: widget.bpm,
          timeTop: widget.timeTop,
        ),
      ),
    );
    if (result == null || !mounted) return;
    // Update sections from editor result; rebuild the rows
    setState(() {
      widget.sections.clear();
      widget.sections.addAll(result.sections);
      _recomputeRows();
    });
  }

  /// Opens the import lyrics & chords sheet.
  Future<void> _importLyrics() async {
    final imported = await showModalBottomSheet<ImportedSong>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ImportLyricsDialog(),
    );
    if (imported == null || imported.sections.isEmpty || !mounted) return;

    var mode = ImportMode.replace;
    if (widget.sections.isNotEmpty) {
      final choice = await showDialog<ImportMode>(
        context: context,
        builder: (dctx) => AlertDialog(
          title: const Text('You already have a song map'),
          content: const Text(
            'Replace it with the imported one, or append the imported sections?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dctx, ImportMode.append),
              child: const Text('Append'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dctx, ImportMode.replace),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (choice == null || !mounted) return;
      mode = choice;
    }

    // Apply imported sections
    if (mode == ImportMode.replace) {
      widget.sections.clear();
    }
    widget.sections.addAll(imported.sections);
    setState(() => _recomputeRows());
  }

  @override
  Widget build(BuildContext context) {
    final lyric =
        Theme.of(context).textTheme.headlineSmall ?? const TextStyle();
    final chordStyle = lyric.copyWith(
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.primary,
    );

    return Scaffold(
      // Pushed imperatively (Navigator.push), so it lives outside go_router
      // and can't use the shell's bottom bar — this screen renders its own
      // pushed-mode bar (Back/title/Menu). Transpose + scroll transport stack
      // above it when there are rows to show. There is no top app bar.
      body: SafeArea(
        bottom: false,
        child: _rows.isEmpty
            ? _EmptyState(
                onOpenEditor: _openSongEditor,
                onImportLyrics: _importLyrics,
              )
            : ListView.builder(
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
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_rows.isNotEmpty)
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
          AppBottomBar.actions(
            onBack: _handleBack,
            title: widget.title,
            onMenu: () => showAppMenuSheet(
              context,
              title: widget.title,
              items: [
                AppMenuItem(
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'Export PDF',
                  onTap: _exportPdf,
                ),
                if (widget.song case final song?)
                  AppMenuItem(
                    icon: Icons.description_outlined,
                    label: 'Export ChordPro',
                    onTap: () => _exportChordPro(song),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom transport for hands-free scrolling: play/pause, ± speed, a
/// Manual ⇄ BPM mode toggle, and live ± transpose (moved here from the
/// AppBar when it gained the standard 3-dot menu, #79).
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
    // Sits above AppBottomBar.actions in the shared bottomNavigationBar
    // Column — that bar owns the bottom (home-indicator) SafeArea inset, so
    // this one only needs the sides.
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onOpenEditor, required this.onImportLyrics});

  final VoidCallback onOpenEditor;
  final VoidCallback onImportLyrics;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MonoPulseSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No lyrics or chords yet.\nAdd them to a section to see the '
              'performance sheet.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: context.mp.textSecondary),
            ),
            const SizedBox(height: MonoPulseSpacing.xl),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: onOpenEditor,
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Open song editor'),
                ),
                const SizedBox(height: MonoPulseSpacing.md),
                OutlinedButton.icon(
                  onPressed: onImportLyrics,
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('Import lyrics & chords'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
