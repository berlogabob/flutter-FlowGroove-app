import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/api_error.dart';
import '../../models/song.dart';
import '../../models/song_suggestion.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/song_form_provider.dart';
import '../../models/section.dart';
import '../../services/api/spotify_proxy_service.dart';
import '../../utils/song_tags.dart';
import '../../widgets/custom_app_bar.dart';
import '../performance_sheet_screen.dart';
import 'components/import_lyrics_dialog.dart';
import '../../widgets/error_banner.dart' show ErrorBanner, ErrorBannerStyle;
import '../../widgets/primary_action_bar.dart';
import '../../widgets/suggestion_selection_dialog.dart';
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
  });
  /// The song to edit. If null, a new song will be created.
  final Song? song;

  /// Optional band ID to associate the song with a band
  final String? bandId;

  final SongFormData? initialFormData;

  @override
  ConsumerState<AddSongScreen> createState() => _AddSongScreenState();
}

class _AddSongScreenState extends ConsumerState<AddSongScreen>
    with AddSongScreenHelper, WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _artistController;
  late TextEditingController _originalBpmController;
  late TextEditingController _ourBpmController;
  late TextEditingController _notesController;

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

    // Spotify suggestions carry no BPM/key at search time — fetch audio-features
    // now (one lazy call) and fill what the user hasn't set.
    final spotifyId = suggestion.spotifyId;
    if (spotifyId != null && spotifyId.isNotEmpty) {
      await _autofillFromSpotify(spotifyId);
    }
  }

  /// Fills BPM and key from Spotify audio-features for [spotifyId], without
  /// overwriting a BPM the user already typed.
  Future<void> _autofillFromSpotify(String spotifyId) async {
    if (_originalBpmController.text.trim().isNotEmpty) return;
    try {
      final features = await SpotifyProxyService.getAudioFeatures(spotifyId);
      if (features == null || !mounted) return;
      if (features.bpm > 0) {
        // The controller's listener syncs this into the form provider.
        _originalBpmController.text = features.bpm.toString();
      }
      _applySpotifyKey(features.musicalKey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Filled ${features.bpm} BPM · ${features.musicalKey} from Spotify',
            ),
          ),
        );
      }
    } catch (_) {
      // Non-fatal — autofill is best-effort (e.g. audio-features unavailable).
    }
  }

  /// Parses a Spotify key string like "C# minor" into the form's base+modifier.
  void _applySpotifyKey(String musicalKey) {
    final parts = musicalKey.trim().split(' ');
    if (parts.isEmpty || parts.first.isEmpty) return;
    final token = parts.first; // e.g. "C#"
    final base = token.replaceAll(RegExp('[#bm]'), '');
    if (base.isEmpty) return;
    var modifier = '';
    if (token.contains('#')) {
      modifier = '#';
    } else if (token.contains('b')) {
      modifier = 'b';
    }
    if (parts.length > 1 && parts[1].toLowerCase() == 'minor') modifier = 'm';
    ref
        .read(songFormStateProvider.notifier)
        .updateOriginalKey(base.substring(0, 1).toUpperCase(), modifier);
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

  @override
  void applyMusicBrainzSuggestion(SongSuggestion suggestion, {int? bpm}) {
    final notifier = ref.read(songFormStateProvider.notifier);
    final currentBpm = ref.read(songFormStateProvider).formData.originalBpm;

    notifier.selectSuggestion(suggestion);
    _titleController.text = suggestion.title;
    _artistController.text = suggestion.artist;

    if (bpm != null && currentBpm.trim().isEmpty) {
      notifier.updateOriginalBpm(bpm.toString());
      _originalBpmController.text = bpm.toString();
    }
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
      Navigator.pop(context);
      showMessage('${formData.title} ${_isEditing ? 'updated' : 'added'}');
    }
  }

  /// Opens the paste-import sheet and appends the parsed sections to the form.
  Future<void> _importLyrics() async {
    final imported = await showModalBottomSheet<List<Section>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ImportLyricsDialog(),
    );
    if (imported == null || imported.isEmpty || !mounted) return;
    final notifier = ref.read(songFormStateProvider.notifier);
    final existing = ref.read(songFormStateProvider).formData.sections;
    notifier.setSections([...existing, ...imported]);
    notifier.markAsChanged();
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
      child: Scaffold(
        appBar: CustomAppBar.build(
          context,
          title: _isEditing ? 'Edit Song' : 'Add Song',
          menuItems: [
            PopupMenuItem<void>(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PerformanceSheetScreen(
                    title: formData.title.trim().isEmpty
                        ? 'Song'
                        : formData.title.trim(),
                    sections: formData.sections,
                  ),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.queue_music),
                  SizedBox(width: 8),
                  Text('Performance sheet'),
                ],
              ),
            ),
            PopupMenuItem<void>(
              onTap: _importLyrics,
              child: const Row(
                children: [
                  Icon(Icons.content_paste),
                  SizedBox(width: 8),
                  Text('Import lyrics & chords'),
                ],
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Error banner
            if (error != null) ...[
              ErrorBanner(
                message: error.message,
                onRetry: () =>
                    ref.read(songFormStateProvider.notifier).clearError(),
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
                ref.read(songFormStateProvider.notifier).markAsChanged();
              },
              onOurKeyChanged: (b, m) {
                ref.read(songFormStateProvider.notifier).updateOurKey(b, m);
                ref.read(songFormStateProvider.notifier).markAsChanged();
              },
              onAddLink: (link) {
                ref.read(songFormStateProvider.notifier).addLink(link);
                ref.read(songFormStateProvider.notifier).markAsChanged();
              },
              onRemoveLink: (index) {
                ref.read(songFormStateProvider.notifier).removeLink(index);
                ref.read(songFormStateProvider.notifier).markAsChanged();
              },
              onTagChanged: (tag, selected) {
                ref
                    .read(songFormStateProvider.notifier)
                    .toggleTag(tag, selected);
                ref.read(songFormStateProvider.notifier).markAsChanged();
              },
              onCopyFromOriginal: () {
                ref.read(songFormStateProvider.notifier).copyFromOriginal();
                _ourBpmController.text = _originalBpmController.text;
                ref.read(songFormStateProvider.notifier).markAsChanged();
              },
              sections: formData.sections,
              onSectionsChanged: (newSections) {
                ref
                    .read(songFormStateProvider.notifier)
                    .setSections(newSections);
                ref.read(songFormStateProvider.notifier).markAsChanged();
              },
              accentBeats: formData.accentBeats,
              regularBeats: formData.regularBeats,
              beatModes: formData.beatModes,
              onAccentBeatsChanged: (value) {
                final notifier = ref.read(songFormStateProvider.notifier);
                notifier.updateAccentBeats(value);
                notifier.initializeBeatModes();
                notifier.markAsChanged();
              },
              onRegularBeatsChanged: (value) {
                final notifier = ref.read(songFormStateProvider.notifier);
                notifier.updateRegularBeats(value);
                notifier.initializeBeatModes();
                notifier.markAsChanged();
              },
              onBeatModeChanged: (beatIndex, subdivisionIndex, mode) {
                final notifier = ref.read(songFormStateProvider.notifier);
                notifier.updateBeatMode(beatIndex, subdivisionIndex, mode);
                notifier.markAsChanged();
              },
              onSuggestionSelected: _handleSuggestionSelected,
              bandId: widget.bandId,
              isEditing: _isEditing,
            ),
            const SizedBox(height: 24),
            // Search buttons row
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: showMusicBrainzSearch,
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('MusicBrainz'),
                  ),
                  TextButton.icon(
                    onPressed: showSpotifySearch,
                    icon: const Icon(Icons.music_note, size: 18),
                    label: const Text('Spotify'),
                  ),
                  TextButton.icon(
                    onPressed: fetchTrackAnalysis,
                    icon: const Icon(Icons.analytics, size: 18),
                    label: const Text('BPM/Key'),
                  ),
                  TextButton.icon(
                    onPressed: searchOnWeb,
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Web'),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: PrimaryActionBar(
          label: _isEditing ? 'Save Changes' : 'Save Song',
          onPressed: isSaving ? null : _saveSong,
          isLoading: isSaving,
        ),
      ),
    );
  }
}
