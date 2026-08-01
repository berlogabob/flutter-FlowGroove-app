import 'package:flutter/material.dart';
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
import '../utils/snackbar.dart';
import '../widgets/app_menu_sheet.dart';
import '../widgets/bottom_nav_or_action_bar.dart';
import '../widgets/performance_sheet_view.dart';
import 'songs/chordpro_sync_controller.dart';
import 'songs/components/import_lyrics_dialog.dart';

/// Full-screen, stage-readable lyrics+chords view for a song: the shared
/// [PerformanceSheetView] body plus stage chrome — wakelock, immersive system
/// UI, and its own pushed-mode bottom bar. Reached from the Song Page's Stage
/// button, Concert Mode, and the add-song draft preview.
class PerformanceSheetScreen extends ConsumerStatefulWidget {
  const PerformanceSheetScreen({
    required this.title,
    required this.sections,
    this.song,
    this.songKey,
    this.bpm,
    this.timeTop,
    this.initialTranspose = 0,
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

  /// Seed transpose (e.g. carried over from the Song Page's Sheet tab).
  final int initialTranspose;

  @override
  ConsumerState<PerformanceSheetScreen> createState() =>
      _PerformanceSheetScreenState();
}

class _PerformanceSheetScreenState
    extends ConsumerState<PerformanceSheetScreen> {
  final GlobalKey<PerformanceSheetViewState> _viewKey = GlobalKey();
  late int _transpose = widget.initialTranspose;
  // Bumped after in-place edits of widget.sections so the view re-parses.
  int _rev = 0;

  // Captured in initState: `ref` is unsafe in dispose() (throws StateError),
  // so hold the controller directly to release the wakelock on close (#96).
  late final WakelockController _wakelock;

  @override
  void initState() {
    super.initState();
    _wakelock = ref.read(wakelockProvider)..enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _wakelock.disable();
    super.dispose();
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
    _viewKey.currentState?.stopScroll();
    Navigator.of(context).pop();
  }

  /// Opens the import lyrics & chords sheet (draft previews only — saved songs
  /// import through the Song Page's Edit tab).
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

    if (mode == ImportMode.replace) {
      widget.sections.clear();
    }
    widget.sections.addAll(imported.sections);
    setState(() => _rev++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Pushed imperatively (Navigator.push), so it lives outside go_router
      // and can't use the shell's bottom bar — this screen renders its own
      // pushed-mode bar (Back/title/Menu). There is no top app bar.
      body: SafeArea(
        bottom: false,
        child: PerformanceSheetView(
          key: _viewKey,
          sections: widget.sections,
          bpm: widget.bpm,
          revision: _rev,
          initialTranspose: widget.initialTranspose,
          onTransposeChanged: (t) => _transpose = t,
          emptyState: _EmptyState(onImportLyrics: _importLyrics),
        ),
      ),
      bottomNavigationBar: AppBottomBar.actions(
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onImportLyrics});

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
            OutlinedButton.icon(
              onPressed: onImportLyrics,
              icon: const Icon(Icons.playlist_add),
              label: const Text('Import lyrics & chords'),
            ),
          ],
        ),
      ),
    );
  }
}
