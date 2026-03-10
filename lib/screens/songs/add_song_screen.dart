import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/api_error.dart';
import '../../models/beat_mode.dart';
import '../../models/song.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/song_form_provider.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/custom_app_bar.dart';
import 'components/song_form.dart';
import 'models/song_form_data.dart';
import 'utils/add_song_screen_helper.dart';

/// Screen for adding or editing a song with comprehensive error handling.
class AddSongScreen extends ConsumerStatefulWidget {
  /// The song to edit. If null, a new song will be created.
  final Song? song;

  /// Optional band ID to associate the song with a band
  final String? bandId;

  const AddSongScreen({super.key, this.song, this.bandId});

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

  final List<String> _availableTags = [
    'ready',
    'learning',
    'hard',
    'slow',
    'fast',
  ];

  bool get _isEditing => widget.song != null;

  @override
  void initState() {
    super.initState();
    _initControllers();
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
    }

    final formData = ref.read(songFormStateProvider).formData;

    _titleController = TextEditingController(text: formData.title);
    _artistController = TextEditingController(text: formData.artist);
    _originalBpmController = TextEditingController(text: formData.originalBpm);
    _ourBpmController = TextEditingController(text: formData.ourBpm);
    _notesController = TextEditingController(text: formData.notes);

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
      ref.read(songFormStateProvider.notifier).setSections(formData.sections);
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

  /// Save the song to Firestore.
  Future<void> _saveSong() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    final userAsync = ref.read(currentUserProvider);
    final user = userAsync.value;
    if (user == null) {
      handleError(ApiError.auth(message: 'Please login to save songs.'));
      return;
    }

    try {
      final songRepo = ref.read(songRepositoryProvider);
      final success = await ref
          .read(songFormStateProvider.notifier)
          .saveSong(
            songRepo: songRepo,
            uid: user.uid,
            bandId: widget.bandId,
            isEditing: _isEditing,
            existingSong: widget.song,
          );

      if (success && mounted) {
        final formData = ref.read(songFormStateProvider).formData;
        Navigator.pop(context);
        showMessage('${formData.title} ${_isEditing ? 'updated' : 'added'}');
      }
    } on ApiError catch (e) {
      debugPrint('ApiError while saving: ${e.message}');
      handleError(e);
      if (mounted) showMessage(e.message);
    } catch (e, stackTrace) {
      debugPrint('Exception while saving: $e');
      final error = ApiError.fromException(e, stackTrace: stackTrace);
      handleError(error);
      if (mounted) showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch form state for reactive updates
    final formState = ref.watch(songFormStateProvider);
    final formData = formState.formData;
    final error = formState.error;
    final isSaving = formState.isSaving;

    return PopScope(
      canPop: true,
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
              onTap: isSaving ? null : _saveSong,
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Error banner
            if (error != null) ...[
              ErrorBanner.banner(
                message: error.message,
                onRetry: () =>
                    ref.read(songFormStateProvider.notifier).clearError(),
              ),
              const SizedBox(height: 16),
            ],
            // Song form
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
              onAccentBeatsChanged: (value) {
                ref
                    .read(songFormStateProvider.notifier)
                    .updateAccentBeats(value);
                ref.read(songFormStateProvider.notifier).initializeBeatModes();
                ref.read(songFormStateProvider.notifier).markAsChanged();
              },
              onRegularBeatsChanged: (value) {
                ref
                    .read(songFormStateProvider.notifier)
                    .updateRegularBeats(value);
                ref.read(songFormStateProvider.notifier).initializeBeatModes();
                ref.read(songFormStateProvider.notifier).markAsChanged();
              },
              onBeatModeChanged:
                  (int beatIndex, int subdivisionIndex, dynamic mode) {
                    ref
                        .read(songFormStateProvider.notifier)
                        .updateBeatMode(beatIndex, subdivisionIndex, mode);
                    ref.read(songFormStateProvider.notifier).markAsChanged();
                  },
              onSectionsChanged: (newSections) {
                ref
                    .read(songFormStateProvider.notifier)
                    .setSections(newSections);
                ref.read(songFormStateProvider.notifier).markAsChanged();
              },
              onSubmit: _saveSong,
              isEditing: _isEditing,
              accentBeats: formData.accentBeats,
              regularBeats: formData.regularBeats,
              beatModes: formData.beatModes,
              sections: formData.sections,
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
      ),
    );
  }
}
