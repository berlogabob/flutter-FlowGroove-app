import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/api_error.dart';
import '../../../providers/auth/error_provider.dart';
import '../../../services/api/spotify_service.dart';
import '../../../services/api/track_analysis_service.dart';
import '../components/spotify_search_section.dart';
import '../components/musicbrainz_search_section.dart';
import '../models/song_form_data.dart';

/// Mixin providing helper methods for the AddSongScreen.
///
/// This mixin contains all the business logic methods for:
/// - Error handling
/// - Track analysis fetching
/// - Search dialogs (Spotify, MusicBrainz, Web)
/// - UI helpers (messages, dialogs)
mixin AddSongScreenHelper<T extends StatefulWidget> on State<T> {
  /// The song form data.
  SongFormData get formData;

  /// The form key for validation.
  GlobalKey<FormState> get formKey;

  /// Whether we are in edit mode.
  bool get isEditing;

  /// The current error (managed by implementing class).
  ApiError? get currentError;

  /// Set the current error.
  set currentError(ApiError? value);

  /// Reference to WidgetRef for provider access.
  WidgetRef get ref;

  /// BuildContext for the state.
  BuildContext get stateContext => context;

  /// Clears the current error.
  void clearError() {
    currentError = null;
  }

  /// Handles an error by updating state and notifying error provider.
  void handleError(ApiError error) {
    currentError = error;
    ref.read(errorStateProvider.notifier).handleError(error);
  }

  /// Fetch track analysis from external API.
  Future<void> fetchTrackAnalysis() async {
    if (formData.title.trim().isEmpty) {
      showMessage('Enter a song title');
      return;
    }

    showMessage('Fetching BPM and key...');

    try {
      final result = await TrackAnalysisService.analyzeTrack(
        formData.title.trim(),
        formData.artist.trim(),
      );

      if (result != null && mounted) {
        setState(() {
          if (result.bpm != null && result.bpm! > 0) {
            formData.updateOriginalBpm(result.bpm.toString());
          }
          if (result.key != null) {
            final key = result.key!;
            formData.originalKeyBase = key
                .replaceAll(RegExp(r'[#bm]'), '')
                .substring(0, 1);
            formData.originalKeyModifier = key.contains('#')
                ? '#'
                : (key.contains('b') ? 'b' : '') +
                      (result.mode == 'minor' ? 'm' : '');
          }
        });
        showMessage(
          result.bpm != null
              ? 'Found: ${result.bpm} BPM, ${result.musicalKey}'
              : 'Could not find track',
        );
      } else if (mounted) {
        showMessage('Track not found. Try a different search.');
      }
    } on ApiError catch (e) {
      handleError(e);
      showMessage(e.message);
    } catch (e, stackTrace) {
      final error = ApiError.fromException(e, stackTrace: stackTrace);
      handleError(error);
      showMessage(error.message);
    }
  }

  /// Show MusicBrainz search bottom sheet.
  void showMusicBrainzSearch() {
    final query = '${formData.title.trim()} ${formData.artist.trim()}'.trim();

    if (query.isEmpty) {
      showMessage('Enter a song title or artist to search');
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
              if (recording.title != null && formData.title.isEmpty) {
                formData.updateTitle(recording.title!);
              }
              if (recording.artist != null && formData.artist.isEmpty) {
                formData.updateArtist(recording.artist!);
              }
              if (recording.bpm != null && formData.originalBpm.isEmpty) {
                formData.updateOriginalBpm(recording.bpm.toString());
              }
            });
            Navigator.pop(context);
            showMessage('Added: ${recording.title} - ${recording.artist}');
          },
        ),
      ),
    );
  }

  /// Show Spotify search bottom sheet.
  void showSpotifySearch() {
    if (!SpotifyService.isConfigured) {
      showMessage(
        'Spotify API not configured. Edit lib/services/spotify_service.dart',
        duration: const Duration(seconds: 4),
      );
      return;
    }

    final query = '${formData.title.trim()} ${formData.artist.trim()}'.trim();

    if (query.isEmpty) {
      showMessage('Enter a song title or artist to search');
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
              if (track.name.isNotEmpty && formData.title.isEmpty) {
                formData.updateTitle(track.name);
              }
              if (track.artist.isNotEmpty && formData.artist.isEmpty) {
                formData.updateArtist(track.artist);
              }
              if (track.spotifyUrl != null && formData.spotifyUrl == null) {
                formData.updateSpotifyUrl(track.spotifyUrl);
              }
              if (features != null &&
                  features.bpm > 0 &&
                  formData.originalBpm.isEmpty) {
                formData.updateOriginalBpm(features.bpm.toString());
                parseKeyFromSpotify(features.musicalKey);
              }
            });
            Navigator.pop(context);
            showMessage('Added: ${track.name} - ${track.artist}');
          },
        ),
      ),
    );
  }

  /// Parse key string from Spotify audio features.
  void parseKeyFromSpotify(String keyString) {
    final keyParts = keyString.split(' ');
    if (keyParts.isNotEmpty) {
      final key = keyParts[0];
      formData.originalKeyBase = key
          .replaceAll(RegExp(r'[#b]'), '')
          .substring(0, 1);
      formData.originalKeyModifier = key.contains('#')
          ? '#'
          : (key.contains('b') ? 'b' : '');
      if (keyParts.length > 1 && keyParts[1] == 'minor') {
        formData.originalKeyModifier = 'm';
      }
    }
  }

  /// Open Spotify search in browser.
  void searchOnWeb() {
    final query = '${formData.title.trim()} ${formData.artist.trim()}'.trim();

    if (query.isEmpty) {
      showMessage('Enter a song title to search');
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
              openUrl(spotifyUrl);
            },
            child: const Text('Open Spotify'),
          ),
        ],
      ),
    );
  }

  /// Open a URL in external browser.
  void openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      showMessage('Could not open: $url');
    }
  }

  /// Show a snackbar message.
  void showMessage(
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(
      stateContext,
    ).showSnackBar(SnackBar(content: Text(message), duration: duration));
  }
}
