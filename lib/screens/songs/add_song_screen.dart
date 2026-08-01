import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../models/api_error.dart';
import '../../models/section.dart';
import '../../models/song.dart';
import '../../models/song_suggestion.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/song_form_provider.dart';
import '../../services/metadata_function_service.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/snackbar.dart';
import '../../utils/song_tags.dart';
import '../../utils/suggestion_links.dart';
import '../../widgets/app_menu_sheet.dart';
import '../../widgets/error_banner.dart' show ErrorBanner;
import '../../widgets/menu_items_scope.dart';
import '../../widgets/primary_action_bar.dart';
import '../../widgets/suggestion_selection_dialog.dart';
import '../performance_sheet_screen.dart';
import 'components/import_lyrics_dialog.dart';
import 'components/song_form.dart';
import 'models/song_form_data.dart';
import 'utils/add_song_screen_helper.dart';

/// Screen for adding or editing a song with comprehensive error handling.
class AddSongScreen extends ConsumerStatefulWidget {
  const AddSongScreen({
    super.key,
    this.song,
    this.bandId,
    this.initialFormData,
    this.embedded = false,
  });

  /// The song to edit. If null, a new song will be created.
  final Song? song;

  /// Optional band ID to associate the song with a band
  final String? bandId;

  final SongFormData? initialFormData;

  /// True when hosted inside the Song Page's Edit tab: the page owns the
  /// shell menu (so nothing is published here) and stays open after a save
  /// (no pop).
  final bool embedded;

  @override
  ConsumerState<AddSongScreen> createState() => _AddSongScreenState();
}

class _AddSongScreenState extends ConsumerState<AddSongScreen>
    with AddSongScreenHelper, WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();

  // `late` matters: the constructor resolves FirebaseFunctions.instance, which
  // throws without an initialised Firebase app. Building this eagerly as a field
  // broke every widget test that merely pumps this screen. Deferring to first
  // use means only a test that actually triggers autofill needs Firebase.
  late final MetadataFunctionService _metadataService =
      MetadataFunctionService();
  late TextEditingController _titleController;
  late TextEditingController _artistController;
  late TextEditingController _originalBpmController;
  late TextEditingController _ourBpmController;
  late TextEditingController _notesController;

  /// True once the post-frame _initControllers has reset/seeded the global
  /// form provider — the form body isn't rendered before that (#78).
  bool _formReady = false;

  bool get _isEditing => widget.song != null;

  /// Suggested tags: the predefined catalogue plus any tags already used across
  /// the user's library, so suggestions grow with their own vocabulary.
  List<String> get _availableTags {
    final libraryTags = ref
        .watch(songsProvider)
        .maybeWhen(
          data: (songs) => songs.expand((s) => s.tags),
          orElse: () => const <String>[],
        );
    return SongTags.normalizeAll([...SongTags.predefined, ...libraryTags]);
  }

  @override
  void initState() {
    super.initState();
    // Initialize controllers immediately to avoid LateInitializationError in build
    _titleController = TextEditingController();
    _artistController = TextEditingController();
    _originalBpmController = TextEditingController();
    _ourBpmController = TextEditingController();
    _notesController = TextEditingController();

    // Delay provider initialization until after the first frame to avoid modifying providers during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initControllers();
        // Body is gated on this: the global form provider still holds the
        // previous song until _initControllers resets it, so rendering the
        // form one frame early flashes stale data (#78).
        setState(() => _formReady = true);
      }
    });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Sync form data with controllers when app resumes
    if (state == AppLifecycleState.resumed) {
      _syncControllersToFormData();
      // Auto-save if there are unsaved changes
      final formState = ref.read(songFormStateProvider);
      if (formState.hasUnsavedChanges && !formState.isAutoSaving) {
        _autoSave();
      }
    }
  }

  Future<void> _autoSave() async {
    final formState = ref.read(songFormStateProvider);
    if (formState.isAutoSaving || !formState.hasUnsavedChanges) return;
    if (_titleController.text.trim().isEmpty) return;

    ref.read(songFormStateProvider.notifier).setAutoSaving(true);

    try {
      final userAsync = ref.read(currentUserProvider);
      final user = userAsync.value;
      if (user == null) return;

      final songRepo = ref.read(songRepositoryProvider);
      final success = await ref
          .read(songFormStateProvider.notifier)
          .autoSave(
            songRepo: songRepo,
            uid: user.uid,
            bandId: widget.bandId,
            isEditing: _isEditing,
            existingSong: widget.song,
          );

      if (success && mounted) {
        debugPrint('✅ Auto-saved song: ${formState.formData.title}');
      }
    } catch (e) {
      if (mounted) {
        ref.read(songFormStateProvider.notifier).setAutoSaving(false);
        debugPrint('❌ Auto-save failed: $e');
      }
    }
  }

  void _initControllers() {
    // Initialize form state from song if editing
    if (_isEditing && widget.song != null) {
      ref.read(songFormStateProvider.notifier).initFromSong(widget.song!);
    } else if (widget.initialFormData != null) {
      ref
          .read(songFormStateProvider.notifier)
          .initFromFormData(widget.initialFormData!);
    } else {
      // Fresh add: the provider is global, so without a reset the form shows
      // the previous session's song and the exit autosave re-writes it as a
      // duplicate (#78).
      ref.read(songFormStateProvider.notifier).reset();
    }

    final formData = ref.read(songFormStateProvider).formData;

    // Set controller text (controllers already created in initState)
    _titleController.text = formData.title;
    _artistController.text = formData.artist;
    _originalBpmController.text = formData.originalBpm;
    _ourBpmController.text = formData.ourBpm;
    _notesController.text = formData.notes;

    // Add listeners to sync controller changes to form data
    _titleController.addListener(() {
      ref
          .read(songFormStateProvider.notifier)
          .updateTitle(_titleController.text);
    });
    _artistController.addListener(() {
      ref
          .read(songFormStateProvider.notifier)
          .updateArtist(_artistController.text);
    });
    _originalBpmController.addListener(() {
      ref
          .read(songFormStateProvider.notifier)
          .updateOriginalBpm(_originalBpmController.text);
    });
    _ourBpmController.addListener(() {
      ref
          .read(songFormStateProvider.notifier)
          .updateOurBpm(_ourBpmController.text);
    });
    _notesController.addListener(() {
      ref
          .read(songFormStateProvider.notifier)
          .updateNotes(_notesController.text);
    });

    // Initialize beat modes for new songs or songs without metronome settings
    if (formData.beatModes.isEmpty) {
      ref.read(songFormStateProvider.notifier).initializeBeatModes();
    }
  }

  void _syncControllersToFormData() {
    ref.read(songFormStateProvider.notifier).updateTitle(_titleController.text);
    ref
        .read(songFormStateProvider.notifier)
        .updateArtist(_artistController.text);
    ref
        .read(songFormStateProvider.notifier)
        .updateOriginalBpm(_originalBpmController.text);
    ref
        .read(songFormStateProvider.notifier)
        .updateOurBpm(_ourBpmController.text);
    ref.read(songFormStateProvider.notifier).updateNotes(_notesController.text);
  }

  /// Handle suggestion selection from autocomplete
  Future<void> _handleSuggestionSelected(SongSuggestion suggestion) async {
    // Show dialog to user
    final action = await showDialog<SuggestionAction>(
      context: context,
      builder: (context) => SuggestionSelectionDialog(suggestion: suggestion),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case SuggestionAction.useExisting:
        // Use existing song - populate form and mark as linked
        ref.read(songFormStateProvider.notifier).selectSuggestion(suggestion);
        _titleController.text = suggestion.title;
        _artistController.text = suggestion.artist;

      case SuggestionAction.fork:
        // Fork to a new editable library song based on the selected source.
        ref.read(songFormStateProvider.notifier).selectSuggestion(suggestion);
        _titleController.text = suggestion.title;
        _artistController.text = suggestion.artist;

      case SuggestionAction.createNew:
        // Create new song - just populate form fields
        ref
            .read(songFormStateProvider.notifier)
            .applySuggestionToForm(suggestion);
        _titleController.text = suggestion.title;
        _artistController.text = suggestion.artist;
    }

    // Record where this came from — auto-fill the Links list from everything
    // we know (MusicBrainz/Spotify deep links + YouTube/chords/lyrics search).
    ref
        .read(songFormStateProvider.notifier)
        .addLinks(linksForSuggestion(suggestion));

    // Suggestions carry no BPM or lyrics at search time. One server call now
    // fills both, plus the release metadata.
    await _autofillFromResolver(suggestion);
  }

  /// Fills BPM and lyric sections from the server-side resolver.
  ///
  /// Replaces three separate client-side fetches (Spotify audio-features, Deezer
  /// BPM, lyrics.ovh) with one callable. Those providers now live in
  /// functions/src/metadata/resolver.js, so the Spotify client secret never
  /// reaches the app bundle and the album heuristic exists in exactly one place.
  ///
  /// Fill-only: anything the user already typed is left alone.
  ///
  /// Deliberately fills no KEY. The old Spotify path defaulted a missing
  /// pitch-class to 0 -> "C", silently reporting "C major from Spotify", which is
  /// a large part of how this library accumulated phantom C values. No provider
  /// exposes musical key, so the field stays empty and honest.
  Future<void> _autofillFromResolver(SongSuggestion suggestion) async {
    final metadata = await _metadataService.lookup(
      title: suggestion.title,
      artist: suggestion.artist,
    );
    if (metadata == null || !mounted) return;

    final filled = <String>[];

    // The album is the whole reason this stage exists. saveSong reads it off the
    // selected suggestion, and a MusicBrainz suggestion's album is
    // `releases.first.title` — arbitrary order, which is how bootlegs like
    // "Apocalypse Now" got stored as real albums. Overwrite with the resolver's
    // properly-picked release before the save can see it.
    if (metadata.found) {
      ref.read(songFormStateProvider.notifier).refineSuggestionMetadata(
            album: metadata.album,
            releaseYear: metadata.releaseYear,
            durationMs: metadata.durationMs,
            musicBrainzId: metadata.musicBrainzId,
            spotifyId: metadata.spotifyId,
          );
      final album = metadata.album;
      if (album != null && album != suggestion.album) {
        final year = metadata.releaseYear;
        filled.add(year == null ? 'album $album' : 'album $album ($year)');
      }
    }

    // The canonical catalog's own BPM wins; otherwise the resolver's (Deezer).
    final bpm = suggestion.bpm ?? metadata.bpm;
    if (bpm != null && bpm > 0 && _originalBpmController.text.trim().isEmpty) {
      // The controller's listener syncs this into the form provider.
      _originalBpmController.text = bpm.toString();
      final source = metadata.sourceOf('bpm');
      filled.add(source == null ? '$bpm BPM' : '$bpm BPM from $source');
    }

    // Lyrics as sections, so they render in the song editor and performance
    // sheet (both read Section.chordChart). Guarded: skip entirely if any
    // section already carries content, so re-selecting never clobbers the
    // user's work or appends a duplicate set.
    final existing = ref.read(songFormStateProvider).formData.sections;
    final hasContent =
        existing.any((s) => (s.chordChart ?? '').trim().isNotEmpty);
    if (metadata.sections.isNotEmpty && !hasContent) {
      final sections = [
        for (final part in metadata.sections)
          Section(
            id: const Uuid().v4(),
            name: part.name,
            chordChart: part.chart,
          ),
      ];
      ref.read(songFormStateProvider.notifier).setSections([
        ...existing,
        ...sections,
      ]);
      final source = metadata.sourceOf('sections') ?? 'lyrics.ovh';
      filled.add('lyrics (${sections.length} parts) from $source');
    }

    if (filled.isNotEmpty && mounted) {
      showAppSnackBar(context, 'Filled ${filled.join(' · ')}');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _titleController.dispose();
    _artistController.dispose();
    _originalBpmController.dispose();
    _ourBpmController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // AddSongScreenHelper implementation
  @override
  SongFormData get formData => ref.read(songFormStateProvider).formData;
  @override
  GlobalKey<FormState> get formKey => _formKey;
  @override
  bool get isEditing => _isEditing;
  @override
  ApiError? get currentError => ref.read(songFormStateProvider).error;
  @override
  set currentError(ApiError? value) {
    ref.read(songFormStateProvider.notifier).setError(value);
  }

  /// Save the song to Firestore with duplicate check.
  Future<void> _saveSong() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    final userAsync = ref.read(currentUserProvider);
    final user = userAsync.value;
    if (user == null) {
      handleError(ApiError.auth(message: 'Please login to save songs.'));
      return;
    }

    final songRepo = ref.read(songRepositoryProvider);
    final success = await ref
        .read(songFormStateProvider.notifier)
        .saveWithDuplicateCheck(
          songRepo: songRepo,
          uid: user.uid,
          context: context,
          bandId: widget.bandId,
          isEditing: _isEditing,
          existingSong: widget.song,
        );

    if (success && mounted) {
      final formData = ref.read(songFormStateProvider).formData;
      if (!widget.embedded) Navigator.pop(context);
      showMessage('${formData.title} ${_isEditing ? 'updated' : 'added'}');
    }
  }

  /// Opens the paste-import sheet and applies the result (metadata + sections)
  /// to the form, appending the parsed sections to any existing ones.
  Future<void> _importLyrics() async {
    final form = ref.read(songFormStateProvider).formData;
    final imported = await showModalBottomSheet<ImportedSong>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ImportLyricsDialog(
        seedTitle: form.title,
        seedArtist: form.artist,
      ),
    );
    if (imported == null || !mounted) return;
    _applyImported(imported);
  }

  /// Applies parsed song metadata + sections to the form. Controllers drive
  /// title/artist/bpm (setting `.text` fires their listeners); key/time/sections
  /// go straight through the notifier. [replaceSections] replaces the section
  /// list (the editor returns the whole map); otherwise it appends.
  void _applyImported(ImportedSong imported, {bool replaceSections = false}) {
    final notifier = ref.read(songFormStateProvider.notifier);
    if (imported.title != null && imported.title!.isNotEmpty) {
      _titleController.text = imported.title!;
    }
    if (imported.artist != null && imported.artist!.isNotEmpty) {
      _artistController.text = imported.artist!;
    }
    if (imported.ourBpm != null) {
      _ourBpmController.text = imported.ourBpm.toString();
    }
    if (imported.ourKey != null && imported.ourKey!.isNotEmpty) {
      final k = imported.ourKey!;
      notifier.updateOurKey(
        k[0].toUpperCase(),
        k.length > 1 ? k.substring(1) : '',
      );
    }
    if (imported.timeTop != null) {
      notifier.updateAccentBeats(imported.timeTop!);
    }
    if (replaceSections) {
      notifier.setSections(imported.sections);
    } else if (imported.sections.isNotEmpty) {
      final existing = ref.read(songFormStateProvider).formData.sections;
      notifier.setSections([...existing, ...imported.sections]);
    }
    notifier.markAsChanged();
  }

  /// Standalone: publish title + menu (draft sheet preview, import) for the
  /// shell bar. Embedded in the Song Page: pass the child through untouched —
  /// publishing here would overwrite the page's menu (same route location).
  Widget _wrapWithMenu({
    required SongFormData formData,
    required Widget child,
  }) {
    if (widget.embedded) return child;
    return MenuScopePublisher(
      data: MenuScopeData(
        // Show the song being edited rather than a generic "Edit Song".
        title: _isEditing
            ? (widget.song!.title.trim().isEmpty
                  ? 'Edit Song'
                  : widget.song!.title.trim())
            : 'Add Song',
        items: [
          AppMenuItem(
            icon: Icons.queue_music,
            label: 'Performance sheet',
            // rootNavigator: cover the whole shell so its persistent bottom
            // bar ("Edit Song") doesn't stack under this screen's own
            // song-name bar (the double-bar bug).
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) => PerformanceSheetScreen(
                  title: formData.title.trim().isEmpty
                      ? 'Song'
                      : formData.title.trim(),
                  sections: formData.sections,
                  songKey: formData.ourKey,
                  bpm: int.tryParse(formData.ourBpm),
                  timeTop: formData.accentBeats,
                ),
              ),
            ),
          ),
          AppMenuItem(
            icon: Icons.content_paste,
            label: 'Import lyrics & chords',
            onTap: _importLyrics,
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch form state for reactive updates
    final formState = ref.watch(songFormStateProvider);
    final formData = formState.formData;
    final error = formState.error;
    final isSaving = formState.isSaving;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop &&
            formState.hasUnsavedChanges &&
            _titleController.text.trim().isNotEmpty) {
          await _autoSave();
        }
      },
      // Pushed branch child: title + actions are published for the shell's
      // bottom bar ([← Back] [title] [⋮ Menu]); there is no top app bar.
      // Embedded (Song Page Edit tab): the page owns the shell menu, so this
      // screen publishes nothing and renders bare.
      child: _wrapWithMenu(
        formData: formData,
        child: Scaffold(
          body: SafeArea(
            bottom: false,
            child: !_formReady
                ? const SizedBox.shrink()
                : ListView(
                    padding: const EdgeInsets.all(MonoPulseSpacing.lg),
                    children: [
                      // Error banner
                      if (error != null) ...[
                        ErrorBanner(
                          message: error.message,
                          onRetry: () => ref
                              .read(songFormStateProvider.notifier)
                              .clearError(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Song form with autocomplete
                      SongForm(
                        formKey: _formKey,
                        titleController: _titleController,
                        artistController: _artistController,
                        originalBpmController: _originalBpmController,
                        ourBpmController: _ourBpmController,
                        notesController: _notesController,
                        links: formData.links,
                        selectedTags: formData.selectedTags,
                        availableTags: _availableTags,
                        originalKeyBase: formData.originalKeyBase,
                        originalKeyModifier: formData.originalKeyModifier,
                        ourKeyBase: formData.ourKeyBase,
                        ourKeyModifier: formData.ourKeyModifier,
                        onOriginalKeyChanged: (b, m) {
                          ref
                              .read(songFormStateProvider.notifier)
                              .updateOriginalKey(b, m);
                          ref
                              .read(songFormStateProvider.notifier)
                              .markAsChanged();
                        },
                        onOurKeyChanged: (b, m) {
                          ref
                              .read(songFormStateProvider.notifier)
                              .updateOurKey(b, m);
                          ref
                              .read(songFormStateProvider.notifier)
                              .markAsChanged();
                        },
                        onAddLink: (link) {
                          ref
                              .read(songFormStateProvider.notifier)
                              .addLink(link);
                          ref
                              .read(songFormStateProvider.notifier)
                              .markAsChanged();
                        },
                        onRemoveLink: (index) {
                          ref
                              .read(songFormStateProvider.notifier)
                              .removeLink(index);
                          ref
                              .read(songFormStateProvider.notifier)
                              .markAsChanged();
                        },
                        onTagChanged: (tag, selected) {
                          ref
                              .read(songFormStateProvider.notifier)
                              .toggleTag(tag, selected);
                          ref
                              .read(songFormStateProvider.notifier)
                              .markAsChanged();
                        },
                        sections: formData.sections,
                        onSectionsChanged: (newSections) {
                          ref
                              .read(songFormStateProvider.notifier)
                              .setSections(newSections);
                          ref
                              .read(songFormStateProvider.notifier)
                              .markAsChanged();
                        },
                        accentBeats: formData.accentBeats,
                        regularBeats: formData.regularBeats,
                        beatModes: formData.beatModes,
                        onAccentBeatsChanged: (value) {
                          final notifier = ref.read(
                            songFormStateProvider.notifier,
                          );
                          notifier.updateAccentBeats(value);
                          notifier.initializeBeatModes();
                          notifier.markAsChanged();
                        },
                        onRegularBeatsChanged: (value) {
                          final notifier = ref.read(
                            songFormStateProvider.notifier,
                          );
                          notifier.updateRegularBeats(value);
                          notifier.initializeBeatModes();
                          notifier.markAsChanged();
                        },
                        onBeatModeChanged: (beatIndex, subdivisionIndex, mode) {
                          final notifier = ref.read(
                            songFormStateProvider.notifier,
                          );
                          notifier.updateBeatMode(
                            beatIndex,
                            subdivisionIndex,
                            mode,
                          );
                          notifier.markAsChanged();
                        },
                        onSuggestionSelected: _handleSuggestionSelected,
                        onSearchWeb: searchOnWeb,
                        bandId: widget.bandId,
                      ),
                    ],
                  ),
          ),
          bottomNavigationBar: PrimaryActionBar(
            label: _isEditing ? 'Save Changes' : 'Save Song',
            onPressed: isSaving ? null : _saveSong,
            isLoading: isSaving,
          ),
        ),
      ),
    );
  }
}
