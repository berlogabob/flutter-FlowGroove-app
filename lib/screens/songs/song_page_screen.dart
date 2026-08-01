import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/song.dart';
import '../../providers/data/data_providers.dart';
import '../../services/export/chordpro_export.dart';
import '../../services/export/pdf_service.dart';
import '../../services/export/setlist_export_sheet.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/snackbar.dart';
import '../../widgets/app_menu_sheet.dart';
import '../../widgets/menu_items_scope.dart';
import '../../widgets/performance_sheet_view.dart';
import '../../widgets/unified_item/song_card_actions.dart';
import '../performance_sheet_screen.dart';
import 'add_song_screen.dart';
import 'song_lab_screen.dart';

/// The song's home: one screen with three modes — Sheet (perform/read),
/// Edit (details + structure), Lab (the song's working journal). Tapping a
/// song anywhere lands here; the shell bar's ⋮ carries the song-wide tools
/// (Metronome, Tuner, Spotify, Add to band, exports).
class SongPageScreen extends ConsumerStatefulWidget {
  const SongPageScreen({
    required this.songId,
    this.initialSong,
    this.bandId,
    this.initialTab,
    super.key,
  });

  final String songId;

  /// Snapshot passed through navigation `extra`; the live stream (personal or
  /// band library) takes over once it emits, so edits and remote changes show
  /// up without re-navigation. Null on deep links / web refresh.
  final Song? initialSong;

  final String? bandId;

  /// 'sheet' (default) | 'edit' | 'lab'.
  final String? initialTab;

  @override
  ConsumerState<SongPageScreen> createState() => _SongPageScreenState();
}

class _SongPageScreenState extends ConsumerState<SongPageScreen>
    with SongCardActions<SongPageScreen> {
  late int _tab = switch (widget.initialTab) {
    'edit' => 1,
    'lab' => 2,
    _ => 0,
  };

  /// Tabs are built lazily on first visit and kept alive after (IndexedStack),
  /// so the Edit tab's global form provider isn't touched until the user
  /// actually edits.
  late final Set<int> _visited = {_tab};

  /// Sheet-tab transpose, forwarded to PDF export and Stage mode.
  int _transpose = 0;

  @override
  String? get songActionsBandId => widget.bandId;

  Song? _liveSong() {
    final async = widget.bandId == null
        ? ref.watch(songsProvider)
        : ref.watch(bandSongsProvider(widget.bandId!));
    final songs = async.value;
    if (songs != null) {
      for (final s in songs) {
        if (s.id == widget.songId) return s;
      }
    }
    return widget.initialSong;
  }

  void _selectTab(int i) {
    setState(() {
      _tab = i;
      _visited.add(i);
    });
  }

  void _openStage(Song song) {
    // rootNavigator: full-screen over the shell so its bottom bar doesn't
    // stack under the stage view's own bar (the double-bar bug).
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => PerformanceSheetScreen(
          title: song.title.trim().isEmpty ? 'Song' : song.title.trim(),
          sections: song.sections,
          song: song,
          songKey: song.ourKey,
          bpm: song.ourBPM ?? song.originalBPM,
          timeTop: song.accentBeats,
          initialTranspose: _transpose,
        ),
      ),
    );
  }

  Future<void> _exportPdf(Song song) async {
    final layout = await pickSongSheetPdfLayout(context);
    if (layout == null) return;
    try {
      await PdfService.exportSongSheet(
        song.title,
        song.sections,
        transpose: _transpose,
        songKey: song.ourKey,
        bpm: song.ourBPM ?? song.originalBPM,
        timeTop: song.accentBeats,
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

  List<AppMenuItem> _menuItems(Song song) {
    final bands = ref.watch(bandsProvider).value ?? const [];
    return [
      AppMenuItem(
        icon: Icons.av_timer,
        label: 'Metronome',
        onTap: () => openInMetronome(song),
      ),
      AppMenuItem(
        icon: Icons.tune,
        label: 'Open in Tuner',
        onTap: () => openInTuner(song),
      ),
      if (song.spotifyUrl != null)
        AppMenuItem(
          icon: Icons.play_circle_fill,
          label: 'Play on Spotify',
          onTap: () => openSpotify(song),
        ),
      if (bands.isNotEmpty)
        AppMenuItem(
          icon: Icons.add_to_queue,
          label: 'Add to band…',
          onTap: () => pickBandAndAdd(song, bands),
        ),
      AppMenuItem(
        icon: Icons.picture_as_pdf_outlined,
        label: 'Export PDF',
        onTap: () => _exportPdf(song),
      ),
      AppMenuItem(
        icon: Icons.description_outlined,
        label: 'Export ChordPro',
        onTap: () => _exportChordPro(song),
      ),
    ];
  }

  Widget _header(Song song) {
    final meta = [
      if (song.artist.trim().isNotEmpty) song.artist.trim(),
      if ((song.ourKey ?? song.originalKey) case final k? when k.isNotEmpty) k,
      if ((song.ourBPM ?? song.originalBPM) case final b?) '$b BPM',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MonoPulseSpacing.lg,
        MonoPulseSpacing.md,
        MonoPulseSpacing.lg,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title.trim().isEmpty ? 'Song' : song.title.trim(),
                  style: MonoPulseTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    style: MonoPulseTypography.labelLarge.copyWith(
                      color: context.mp.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (_tab == 0 && song.hasSheetContent)
            IconButton.filledTonal(
              onPressed: () => _openStage(song),
              icon: const Icon(Icons.fullscreen),
              tooltip: 'Stage mode',
            ),
        ],
      ),
    );
  }

  Widget _sheetTab(Song song) {
    return PerformanceSheetView(
      sections: song.sections,
      bpm: song.ourBPM ?? song.originalBPM,
      initialTranspose: _transpose,
      onTransposeChanged: (t) => _transpose = t,
      emptyState: Center(
        child: Padding(
          padding: const EdgeInsets.all(MonoPulseSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'No lyrics or chords yet.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: context.mp.textSecondary,
                ),
              ),
              const SizedBox(height: MonoPulseSpacing.xl),
              FilledButton.icon(
                onPressed: () => _selectTab(1),
                icon: const Icon(Icons.edit_note),
                label: const Text('Add lyrics & chords'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final song = _liveSong();
    if (song == null) {
      // Deep link / refresh before the library stream has emitted.
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return MenuScopePublisher(
      data: MenuScopeData(
        title: song.title.trim().isEmpty ? 'Song' : song.title.trim(),
        items: _menuItems(song),
      ),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(song),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MonoPulseSpacing.lg,
                  MonoPulseSpacing.md,
                  MonoPulseSpacing.lg,
                  MonoPulseSpacing.sm,
                ),
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('Sheet'),
                      icon: Icon(Icons.queue_music),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('Edit'),
                      icon: Icon(Icons.edit_outlined),
                    ),
                    ButtonSegment(
                      value: 2,
                      label: Text('Lab'),
                      icon: Icon(Icons.science_outlined),
                    ),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (s) => _selectTab(s.first),
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: _tab,
                  children: [
                    if (_visited.contains(0))
                      _sheetTab(song)
                    else
                      const SizedBox.shrink(),
                    if (_visited.contains(1))
                      AddSongScreen(
                        key: ValueKey('edit-${widget.songId}'),
                        song: song,
                        bandId: widget.bandId,
                        embedded: true,
                      )
                    else
                      const SizedBox.shrink(),
                    if (_visited.contains(2))
                      SongLabScreen(
                        key: ValueKey('lab-${widget.songId}'),
                        song: song,
                        bandId: widget.bandId,
                        embedded: true,
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
