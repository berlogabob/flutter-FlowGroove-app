import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/api_error.dart';
import '../../models/song.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/auth/auth_provider.dart';
import '../../widgets/error_banner.dart';
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
  late SongFormData _formData;
  late TextEditingController _titleController;
  late TextEditingController _artistController;
  late TextEditingController _originalBpmController;
  late TextEditingController _ourBpmController;
  late TextEditingController _notesController;
  ApiError? _currentError;

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
    _formData = _isEditing
        ? SongFormData.fromSong(widget.song!)
        : SongFormData();
    _initControllers();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Sync form data with controllers when app resumes
    if (state == AppLifecycleState.resumed) {
      _syncControllersToFormData();
    }
  }

  void _initControllers() {
    _titleController = TextEditingController(text: _formData.title);
    _artistController = TextEditingController(text: _formData.artist);
    _originalBpmController = TextEditingController(text: _formData.originalBpm);
    _ourBpmController = TextEditingController(text: _formData.ourBpm);
    _notesController = TextEditingController(text: _formData.notes);

    // Add listeners to sync controller changes to form data
    _titleController.addListener(
      () => _formData.updateTitle(_titleController.text),
    );
    _artistController.addListener(
      () => _formData.updateArtist(_artistController.text),
    );
    _originalBpmController.addListener(
      () => _formData.updateOriginalBpm(_originalBpmController.text),
    );
    _ourBpmController.addListener(
      () => _formData.updateOurBpm(_ourBpmController.text),
    );
    _notesController.addListener(
      () => _formData.updateNotes(_notesController.text),
    );
  }

  void _syncControllersToFormData() {
    _formData.updateTitle(_titleController.text);
    _formData.updateArtist(_artistController.text);
    _formData.updateOriginalBpm(_originalBpmController.text);
    _formData.updateOurBpm(_ourBpmController.text);
    _formData.updateNotes(_notesController.text);
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
  SongFormData get formData => _formData;
  @override
  GlobalKey<FormState> get formKey => _formKey;
  @override
  bool get isEditing => _isEditing;
  @override
  ApiError? get currentError => _currentError;
  @override
  set currentError(ApiError? value) {
    setState(() => _currentError = value);
  }

  /// Save the song to Firestore.
  Future<void> _saveSong() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) {
      handleError(ApiError.auth(message: 'Please login to save songs.'));
      return;
    }

    try {
      final song = _formData.toSong(
        id: _isEditing ? widget.song!.id : const Uuid().v4(),
        createdAt: _isEditing ? widget.song!.createdAt : DateTime.now(),
        bandId: widget.bandId,
      );

      final firestore = ref.read(firestoreProvider);

      // If bandId is provided, save to band's collection
      if (widget.bandId != null) {
        await firestore.saveBandSong(song, widget.bandId!);
      } else {
        await firestore.saveSong(song, user.uid);
      }

      if (mounted) {
        Navigator.pop(context);
        showMessage('${song.title} ${_isEditing ? 'updated' : 'added'}');
      }
    } on ApiError catch (e) {
      handleError(e);
      if (mounted) showMessage(e.message);
    } catch (e, stackTrace) {
      final error = ApiError.fromException(e, stackTrace: stackTrace);
      handleError(error);
      if (mounted) showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Song' : 'Add Song'),
        actions: [
          TextButton(
            onPressed: _saveSong,
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Error banner
          if (_currentError != null) ...[
            ErrorBanner.banner(
              message: _currentError!.message,
              onRetry: clearError,
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
            links: _formData.links,
            selectedTags: _formData.selectedTags,
            availableTags: _availableTags,
            originalKeyBase: _formData.originalKeyBase,
            originalKeyModifier: _formData.originalKeyModifier,
            ourKeyBase: _formData.ourKeyBase,
            ourKeyModifier: _formData.ourKeyModifier,
            onOriginalKeyChanged: (b, m) => setState(() {
              _formData.originalKeyBase = b;
              _formData.originalKeyModifier = m;
            }),
            onOurKeyChanged: (b, m) => setState(() {
              _formData.ourKeyBase = b;
              _formData.ourKeyModifier = m;
            }),
            onAddLink: (link) => setState(() => _formData.addLink(link)),
            onRemoveLink: (index) =>
                setState(() => _formData.removeLink(index)),
            onTagChanged: (tag, selected) =>
                setState(() => _formData.toggleTag(tag, selected)),
            onCopyFromOriginal: () => setState(() {
              _formData.copyFromOriginal();
              _ourBpmController.text = _originalBpmController.text;
            }),
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
    );
  }
}
