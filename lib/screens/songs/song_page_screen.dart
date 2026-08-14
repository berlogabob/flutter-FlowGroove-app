import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/song.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/song_form_provider.dart';
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
import 'components/import_lyrics_dialog.dart';
import 'song_editor_screen.dart';
import 'song_lab_screen.dart';

/// Song Page tab order — enum declaration order drives both the segment row
/// and the IndexedStack, so they can't drift apart.
enum _SongTab { edit, sheet, lab }

/// The song's home: one screen with three modes — Edit (details + structure),
/// Sheet (perform/read), Lab (the song's working journal). Tapping a
/// song anywhere lands here; the shell bar's ⋮ carries the song-wide tools
/// (Metronome, Tuner, Spotify, Add to band, exports, song editor).
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

  /// 'edit' (default) | 'sheet' | 'lab'.
  final String? initialTab;

  @override
  ConsumerState<SongPageScreen> createState() => _SongPageScreenState();
}

class _SongPageScreenState extends ConsumerState<SongPageScreen>
    with SongCardActions<SongPageScreen> {
  late _SongTab _tab = switch (widget.initialTab) {
    'sheet' => _SongTab.sheet,
    'lab' => _SongTab.lab,
    _ => _SongTab.edit,
  };

  /// Tabs are built lazily on first visit and kept alive after (IndexedStack),
  /// so unvisited tabs (e.g. the Lab) cost nothing until opened.
  late final Set<_SongTab> _visited = {_tab};

  /// Sheet-tab transpose, forwarded to PDF export and Stage mode.
  int _transpose = 0;

  /// Bumped after the full-screen song editor saves, so an already-built
  /// Edit tab re-keys and re-inits its form from the saved song.
  int _editEpoch = 0;

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

  void _selectTab(_SongTab t) {
    setState(() {
      _tab = t;
      _visited.add(t);
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

  /// Full-screen map + ChordPro editor for the whole song; saves directly
  /// to the library on close (user decision — no staging through the form).
  Future<void> _openSongEditor(Song song) async {
    if (!_canEditSongNow()) {
      showAppSnackBar(context, 'Only band editors can change this song');
      return;
    }
    // The editor writes straight to the song, so refuse while the Edit tab
    // holds unsaved form changes — merging the two silently would lose one.
    if (_visited.contains(_SongTab.edit) &&
        ref.read(songFormStateProvider).hasUnsavedChanges) {
      showAppSnackBar(context, 'Save or discard your Edit changes first');
      return;
    }
    // rootNavigator: full-screen editor with its own bottom bar over the
    // shell (the double-bar bug).
    final result = await Navigator.of(context, rootNavigator: true)
        .push<ImportedSong>(
          MaterialPageRoute(
            builder: (_) => SongEditorScreen(
              title: song.title,
              sections: song.sections,
              artist: song.artist,
              songKey: song.ourKey,
              bpm: song.ourBPM ?? song.originalBPM,
              timeTop: song.accentBeats,
            ),
          ),
        );
    if (result == null || !mounted) return;
    final trimmedTitle = result.title?.trim();
    final trimmedArtist = result.artist?.trim();
    final updated = song.copyWith(
      sections: result.sections,
      title: (trimmedTitle?.isNotEmpty ?? false) ? trimmedTitle : null,
      artist: (trimmedArtist?.isNotEmpty ?? false) ? trimmedArtist : null,
      ourKey: result.ourKey ?? song.ourKey,
      ourBPM: result.ourBpm ?? song.ourBPM,
      accentBeats: result.timeTop,
    );
    try {
      final repo = ref.read(songRepositoryProvider);
      if (widget.bandId case final b?) {
        await repo.updateBandSong(updated, b);
      } else {
        await repo.updateSong(
          updated,
          uid: ref.read(currentUserProvider).value?.uid,
        );
      }
      if (mounted) setState(() => _editEpoch++);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, 'Save failed: $e');
    }
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

  /// Can this user modify the song? Band copies need the editor/admin role
  /// (same arrays the Firestore rules read); personal songs need a signed-in
  /// non-demo user. The old band songs screen gated on this — the unified
  /// page must too, or viewers get an editor that fails only at save time.
  bool _canEditSong() {
    if (widget.bandId case final b?) {
      return ref.watch(canEditBandProvider(b));
    }
    return ref.watch(currentUserProvider).value != null &&
        !ref.watch(isDemoUserProvider);
  }

  /// Event-handler variant of [_canEditSong] — `ref.watch` outside build is
  /// invalid, so handlers re-check with `ref.read`.
  bool _canEditSongNow() {
    if (widget.bandId case final b?) {
      return ref.read(canEditBandProvider(b));
    }
    return ref.read(currentUserProvider).value != null &&
        !ref.read(isDemoUserProvider);
  }

  List<AppMenuItem> _menuItems(Song song) {
    // Only bands the user can write to — viewers' bands would fail at save.
    final bands = editableBands(ref.watch(bandsProvider).value ?? const []);
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
      if (_canEditSong())
        AppMenuItem(
          icon: Icons.edit_note,
          label: 'Song editor',
          onTap: () => _openSongEditor(song),
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

  Widget _header(Song song, _SongTab activeTab) {
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
          if (activeTab == _SongTab.sheet && song.hasSheetContent)
            IconButton.filledTonal(
              onPressed: () => _openStage(song),
              icon: const Icon(Icons.fullscreen),
              tooltip: 'Stage mode',
            ),
        ],
      ),
    );
  }

  Widget _sheetTab(Song song, {required bool canEdit}) {
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
              // Second door into the Edit tab — hidden with it for viewers.
              if (canEdit)
                FilledButton.icon(
                  onPressed: () => _selectTab(_SongTab.edit),
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

    // Band copies hide the Edit tab from non-editors (the save would only be
    // rules-denied); personal songs keep the default Edit-first behavior.
    // Derived per build — NOT written back to _tab — so an editor whose
    // permissions are still loading (gate temporarily false) lands on Edit
    // once the bands stream emits.
    final editVisible = widget.bandId == null || _canEditSong();
    final activeTab = !editVisible && _tab == _SongTab.edit
        ? _SongTab.sheet
        : _tab;
    // The coerced Sheet must render even if only Edit was "visited".
    final built = {..._visited, activeTab};

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
              _header(song, activeTab),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MonoPulseSpacing.lg,
                  MonoPulseSpacing.md,
                  MonoPulseSpacing.lg,
                  MonoPulseSpacing.sm,
                ),
                child: SegmentedButton<_SongTab>(
                  showSelectedIcon: false,
                  segments: [
                    if (editVisible)
                      const ButtonSegment(
                        value: _SongTab.edit,
                        label: Text('Edit'),
                        icon: Icon(Icons.edit_outlined),
                      ),
                    const ButtonSegment(
                      value: _SongTab.sheet,
                      label: Text('Sheet'),
                      icon: Icon(Icons.queue_music),
                    ),
                    const ButtonSegment(
                      value: _SongTab.lab,
                      label: Text('Lab'),
                      icon: Icon(Icons.science_outlined),
                    ),
                  ],
                  selected: {activeTab},
                  onSelectionChanged: (s) => _selectTab(s.first),
                ),
              ),
              Expanded(
                // Fixed 3-slot stack: slots never shift when the Edit segment
                // is hidden, so Sheet/Lab keep their state and index.
                child: IndexedStack(
                  index: activeTab.index,
                  children: [
                    // Not just hidden: an embedded AddSongScreen stays a live
                    // lifecycle observer that would keep attempting saves.
                    if (editVisible && built.contains(_SongTab.edit))
                      AddSongScreen(
                        key: ValueKey('edit-${widget.songId}-$_editEpoch'),
                        song: song,
                        bandId: widget.bandId,
                        embedded: true,
                      )
                    else
                      const SizedBox.shrink(),
                    if (built.contains(_SongTab.sheet))
                      _sheetTab(song, canEdit: editVisible)
                    else
                      const SizedBox.shrink(),
                    if (built.contains(_SongTab.lab))
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
