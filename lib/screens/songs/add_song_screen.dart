import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/data_providers.dart';
import '../../providers/auth_provider.dart';
import '../../models/song.dart';
import '../../models/link.dart';
import '../../services/spotify_service.dart';
import '../../services/track_analysis_service.dart';
import 'components/song_form.dart';
import 'components/spotify_search_section.dart';
import 'components/musicbrainz_search_section.dart';

/// Screen for adding or editing a song.
///
/// This screen provides a form for entering song details including
/// title, artist, key, BPM, links, notes, and tags. It supports
/// fetching track information from Spotify and MusicBrainz.
class AddSongScreen extends ConsumerStatefulWidget {
  /// The song to edit. If null, a new song will be created.
  final Song? song;

  const AddSongScreen({super.key, this.song});

  @override
  ConsumerState<AddSongScreen> createState() => _AddSongScreenState();
}

class _AddSongScreenState extends ConsumerState<AddSongScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _originalBpmController = TextEditingController();
  final _ourBpmController = TextEditingController();
  final _notesController = TextEditingController();
  final List<Link> _links = [];
  final List<String> _selectedTags = [];
  String? _spotifyUrl;

  String _originalKeyBase = 'C';
  String _originalKeyModifier = '';
  String _ourKeyBase = 'C';
  String _ourKeyModifier = '';

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
    if (_isEditing) {
      _initializeFromSong(widget.song!);
    }
  }

  /// Initialize form fields from an existing song.
  void _initializeFromSong(Song song) {
    setState(() {
      _titleController.text = song.title;
      _artistController.text = song.artist;
      _originalBpmController.text = song.originalBPM?.toString() ?? '';
      _ourBpmController.text = song.ourBPM?.toString() ?? '';
      _notesController.text = song.notes ?? '';
      _links.addAll(song.links);
      _selectedTags.addAll(song.tags);
      _spotifyUrl = song.spotifyUrl;
      _parseKey(song.originalKey, isOriginal: true);
      _parseKey(song.ourKey, isOriginal: false);
    });
  }

  /// Parse a key string into base and modifier components.
  void _parseKey(String? key, {required bool isOriginal}) {
    if (key == null || key.isEmpty) return;

    final setStateCallback = isOriginal
        ? (base, modifier) {
            _originalKeyBase = base;
            _originalKeyModifier = modifier;
          }
        : (base, modifier) {
            _ourKeyBase = base;
            _ourKeyModifier = modifier;
          };

    if (key.length > 1 && key.endsWith('m')) {
      setStateCallback(key[0].toUpperCase(), 'm');
    } else if (key.length > 1) {
      setStateCallback(key[0].toUpperCase(), key.substring(1));
    } else {
      setStateCallback(key.toUpperCase(), '');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _originalBpmController.dispose();
    _ourBpmController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Build a key string from base and modifier.
  String _buildKey(String base, String modifier) {
    if (modifier == 'm') return '${base.toLowerCase()}m';
    return '$base$modifier';
  }

  /// Copy key and BPM from original to "our" fields.
  void _copyFromOriginal() {
    setState(() {
      _ourKeyBase = _originalKeyBase;
      _ourKeyModifier = _originalKeyModifier;
      _ourBpmController.text = _originalBpmController.text;
    });
  }

  /// Fetch track analysis from external API.
  Future<void> _fetchTrackAnalysis() async {
    final title = _titleController.text.trim();
    final artist = _artistController.text.trim();

    if (title.isEmpty) {
      _showMessage('Enter a song title');
      return;
    }

    _showMessage('Fetching BPM and key...');

    try {
      final result = await TrackAnalysisService.analyzeTrack(title, artist);

      if (result != null && mounted) {
        setState(() {
          if (result.bpm != null && result.bpm! > 0) {
            _originalBpmController.text = result.bpm.toString();
          }
          if (result.key != null) {
            final key = result.key!;
            _originalKeyBase = key.replaceAll(RegExp(r'[#bm]'), '').substring(0, 1);
            _originalKeyModifier = key.contains('#')
                ? '#'
                : (key.contains('b') ? 'b' : '') + (result.mode == 'minor' ? 'm' : '');
          }
        });
        _showMessage(
          result.bpm != null
              ? 'Found: ${result.bpm} BPM, ${result.musicalKey}'
              : 'Could not find track',
        );
      } else if (mounted) {
        _showMessage('Track not found. Try a different search.');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error: $e');
      }
    }
  }

  /// Show MusicBrainz search bottom sheet.
  void _showMusicBrainzSearch() {
    final query = '${_titleController.text.trim()} ${_artistController.text.trim()}'.trim();

    if (query.isEmpty) {
      _showMessage('Enter a song title or artist to search');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => MusicBrainzSearchSection(
          query: query,
          scrollController: scrollController,
          onSelect: (recording) {
            setState(() {
              if (recording.title != null && _titleController.text.isEmpty) {
                _titleController.text = recording.title!;
              }
              if (recording.artist != null && _artistController.text.isEmpty) {
                _artistController.text = recording.artist!;
              }
              if (recording.bpm != null && _originalBpmController.text.isEmpty) {
                _originalBpmController.text = recording.bpm.toString();
              }
            });
            Navigator.pop(context);
            _showMessage('Added: ${recording.title} - ${recording.artist}');
          },
        ),
      ),
    );
  }

  /// Show Spotify search bottom sheet.
  void _showSpotifySearch() {
    if (!SpotifyService.isConfigured) {
      _showMessage(
        'Spotify API not configured. Edit lib/services/spotify_service.dart',
        duration: const Duration(seconds: 4),
      );
      return;
    }

    final query = '${_titleController.text.trim()} ${_artistController.text.trim()}'.trim();

    if (query.isEmpty) {
      _showMessage('Enter a song title or artist to search');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SpotifySearchSection(
          query: query,
          scrollController: scrollController,
          onSelect: (track, features) {
            setState(() {
              if (track.name.isNotEmpty && _titleController.text.isEmpty) {
                _titleController.text = track.name;
              }
              if (track.artist.isNotEmpty && _artistController.text.isEmpty) {
                _artistController.text = track.artist;
              }
              if (track.spotifyUrl != null && _spotifyUrl == null) {
                _spotifyUrl = track.spotifyUrl;
              }
              if (features != null &&
                  features.bpm > 0 &&
                  _originalBpmController.text.isEmpty) {
                _originalBpmController.text = features.bpm.toString();
                _parseKeyFromSpotify(features.musicalKey);
              }
            });
            Navigator.pop(context);
            _showMessage('Added: ${track.name} - ${track.artist}');
          },
        ),
      ),
    );
  }

  /// Parse key string from Spotify audio features.
  void _parseKeyFromSpotify(String keyString) {
    final keyParts = keyString.split(' ');
    if (keyParts.isNotEmpty) {
      final key = keyParts[0];
      _originalKeyBase = key.replaceAll(RegExp(r'[#b]'), '').substring(0, 1);
      _originalKeyModifier =
          key.contains('#') ? '#' : (key.contains('b') ? 'b' : '');
      if (keyParts.length > 1 && keyParts[1] == 'minor') {
        _originalKeyModifier = 'm';
      }
    }
  }

  /// Open Spotify search in browser.
  void _searchOnWeb() {
    final query = '${_titleController.text.trim()} ${_artistController.text.trim()}'.trim();

    if (query.isEmpty) {
      _showMessage('Enter a song title to search');
      return;
    }

    final encodedQuery = Uri.encodeComponent(query);
    final spotifyUrl = 'https://open.spotify.com/search/$encodedQuery';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search on Web'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Open Spotify search in browser?'),
            const SizedBox(height: 16),
            Text(query, style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openUrl(spotifyUrl);
            },
            child: const Text('Open Spotify'),
          ),
        ],
      ),
    );
  }

  /// Open a URL in external browser.
  void _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      _showMessage('Could not open: $url');
    }
  }

  /// Show a snackbar message.
  void _showMessage(String message, {Duration duration = const Duration(seconds: 2)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: duration),
    );
  }

  /// Save the song to Firestore.
  Future<void> _saveSong() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) {
      _showMessage('Please login first');
      return;
    }

    final originalKey = _buildKey(_originalKeyBase, _originalKeyModifier);
    final ourKey = _buildKey(_ourKeyBase, _ourKeyModifier);

    try {
      final song = Song(
        id: _isEditing ? widget.song!.id : const Uuid().v4(),
        title: _titleController.text.trim(),
        artist: _artistController.text.trim(),
        originalKey: originalKey.isNotEmpty ? originalKey : null,
        originalBPM: _originalBpmController.text.trim().isNotEmpty
            ? int.tryParse(_originalBpmController.text.trim())
            : null,
        ourKey: ourKey.isNotEmpty ? ourKey : null,
        ourBPM: _ourBpmController.text.trim().isNotEmpty
            ? int.tryParse(_ourBpmController.text.trim())
            : null,
        links: _links,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        tags: _selectedTags,
        spotifyUrl: _spotifyUrl,
        createdAt: _isEditing ? widget.song!.createdAt : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final firestore = ref.read(firestoreProvider);
      await firestore.saveSong(song, user.uid);

      if (mounted) {
        Navigator.pop(context);
        _showMessage('${song.title} ${_isEditing ? 'updated' : 'added'}');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error: $e');
      }
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
          // Song form with all fields
          SongForm(
            formKey: _formKey,
            titleController: _titleController,
            artistController: _artistController,
            originalBpmController: _originalBpmController,
            ourBpmController: _ourBpmController,
            notesController: _notesController,
            links: _links,
            selectedTags: _selectedTags,
            availableTags: _availableTags,
            originalKeyBase: _originalKeyBase,
            originalKeyModifier: _originalKeyModifier,
            ourKeyBase: _ourKeyBase,
            ourKeyModifier: _ourKeyModifier,
            onOriginalKeyChanged: (b, m) => setState(() {
              _originalKeyBase = b;
              _originalKeyModifier = m;
            }),
            onOurKeyChanged: (b, m) => setState(() {
              _ourKeyBase = b;
              _ourKeyModifier = m;
            }),
            onAddLink: (link) => setState(() => _links.add(link)),
            onRemoveLink: (index) => setState(() => _links.removeAt(index)),
            onTagChanged: (tag, selected) => setState(() {
              if (selected) {
                _selectedTags.add(tag);
              } else {
                _selectedTags.remove(tag);
              }
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
                  onPressed: _showMusicBrainzSearch,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('MusicBrainz'),
                ),
                TextButton.icon(
                  onPressed: _showSpotifySearch,
                  icon: const Icon(Icons.music_note, size: 18),
                  label: const Text('Spotify'),
                ),
                TextButton.icon(
                  onPressed: _fetchTrackAnalysis,
                  icon: const Icon(Icons.analytics, size: 18),
                  label: const Text('BPM/Key'),
                ),
                TextButton.icon(
                  onPressed: _searchOnWeb,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Web'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Copy from original button
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _copyFromOriginal,
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy from Original'),
            ),
          ),
        ],
      ),
    );
  }
}
