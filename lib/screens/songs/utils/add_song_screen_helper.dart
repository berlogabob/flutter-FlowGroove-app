import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/api_error.dart';
import '../../../providers/auth/error_provider.dart';
import '../models/song_form_data.dart';

/// Mixin providing helper methods for the AddSongScreen.
///
/// This mixin contains all the business logic methods for:
/// - Error handling
/// - Web search shortcut
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

  /// Open Spotify search in browser.
  void searchOnWeb() {
    final query = '${formData.title.trim()} ${formData.artist.trim()}'.trim();

    if (query.isEmpty) {
      showMessage('Enter a song title to search');
      return;
    }

    final encodedQuery = Uri.encodeComponent(query);
    final spotifyUrl = 'https://open.spotify.com/search/$encodedQuery';

    showDialog<void>(
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
  Future<void> openUrl(String url) async {
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
