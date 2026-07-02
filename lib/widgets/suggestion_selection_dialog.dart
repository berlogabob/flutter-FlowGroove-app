import 'package:flutter/material.dart';
import '../models/song_suggestion.dart';
import '../theme/mono_pulse_theme.dart';

/// Suggestion selection dialog
/// 
/// Shown when user selects an existing song from autocomplete.
/// Provides options:
/// - "Use This Song" - Link to existing and customize
/// - "Fork to Personal" - Create personal copy (for group songs)
/// - "Create New" - Start fresh with this info
/// 
/// Usage:
/// ```dart
/// final result = await showDialog<SuggestionAction>(
///   context: context,
///   builder: (context) => SuggestionSelectionDialog(
///     suggestion: suggestion,
///   ),
/// );
/// ```
class SuggestionSelectionDialog extends StatelessWidget {

  const SuggestionSelectionDialog({
    required this.suggestion,
    super.key,
  });
  final SongSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      icon: _buildIcon(context),
      title: Text(_getTitle()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Song details
          _SongDetailRow(
            icon: Icons.music_note,
            label: 'Song',
            value: suggestion.title,
          ),
          const SizedBox(height: 8),
          _SongDetailRow(
            icon: Icons.person,
            label: 'Artist',
            value: suggestion.artist,
          ),
          if (suggestion.album != null) ...[
            const SizedBox(height: 8),
            _SongDetailRow(
              icon: Icons.album,
              label: 'Album',
              value: suggestion.album!,
            ),
          ],
          if (suggestion.releaseYear != null) ...[
            const SizedBox(height: 8),
            _SongDetailRow(
              icon: Icons.calendar_today,
              label: 'Year',
              value: suggestion.releaseYear.toString(),
            ),
          ],
          if (suggestion.bpm != null) ...[
            const SizedBox(height: 8),
            _SongDetailRow(
              icon: Icons.speed,
              label: 'BPM',
              value: '${suggestion.bpm}',
            ),
          ],
          if (suggestion.key != null) ...[
            const SizedBox(height: 8),
            _SongDetailRow(
              icon: Icons.music_note,
              label: 'Key',
              value: suggestion.key!,
            ),
          ],
          
          const Divider(height: 24),
          
          // Source info
          Row(
            children: [
              Icon(
                _getSourceIcon(),
                size: 16,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: 6),
              Text(
                _getSourceText(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: _buildActions(context),
      actionsPadding: const EdgeInsets.symmetric(
        horizontal: MonoPulseSpacing.lg,
        vertical: MonoPulseSpacing.sm,
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    switch (suggestion.source) {
      case SuggestionSource.personal:
        return Icon(Icons.person, color: Theme.of(context).colorScheme.primary);
      case SuggestionSource.group:
        return Icon(Icons.group, color: Theme.of(context).colorScheme.secondary);
      case SuggestionSource.musicbrainz:
        return const Icon(Icons.cloud, color: MonoPulseColors.successGreen);
      case SuggestionSource.spotify:
        return const Icon(Icons.music_note, color: MonoPulseColors.successGreen);
      case SuggestionSource.canonical:
        return Icon(Icons.library_music, color: Theme.of(context).colorScheme.tertiary);
    }
  }

  String _getTitle() {
    switch (suggestion.source) {
      case SuggestionSource.personal:
        return 'Song Already in Your Library';
      case SuggestionSource.group:
        return 'Song in Band Library';
      case SuggestionSource.musicbrainz:
        return 'Found in MusicBrainz';
      case SuggestionSource.spotify:
        return 'Found on Spotify';
      case SuggestionSource.canonical:
        return 'Song in Database';
    }
  }

  IconData _getSourceIcon() {
    switch (suggestion.source) {
      case SuggestionSource.personal:
        return Icons.person;
      case SuggestionSource.group:
        return Icons.group;
      case SuggestionSource.musicbrainz:
        return Icons.cloud;
      case SuggestionSource.spotify:
        return Icons.music_note;
      case SuggestionSource.canonical:
        return Icons.library_music;
    }
  }

  String _getSourceText() {
    switch (suggestion.source) {
      case SuggestionSource.personal:
        return 'Already in your personal library';
      case SuggestionSource.group:
        return 'In ${suggestion.bandName ?? "your band"} • ${suggestion.matchScore.toStringAsFixed(0).padLeft(3)}% match';
      case SuggestionSource.musicbrainz:
        return 'From MusicBrainz database';
      case SuggestionSource.spotify:
        return 'From Spotify • adds BPM/key on selection';
      case SuggestionSource.canonical:
        return 'In song database • ${suggestion.matchScore.toStringAsFixed(0).padLeft(3)}% match';
    }
  }

  List<Widget> _buildActions(BuildContext context) {
    final actions = <Widget>[];

    // Primary action: Use this song
    actions.add(
      FilledButton(
        onPressed: () => Navigator.pop(context, SuggestionAction.useExisting),
        child: Text(
          suggestion.source == SuggestionSource.personal
              ? 'Open Song'
              : 'Use This Song',
        ),
      ),
    );

    // Fork action (only for group songs)
    if (suggestion.isForkable) {
      actions.add(
        TextButton.icon(
          onPressed: () => Navigator.pop(context, SuggestionAction.fork),
          icon: const Icon(Icons.call_split),
          label: const Text('Fork to Personal'),
        ),
      );
    }

    // Create new action
    actions.add(
      TextButton(
        onPressed: () => Navigator.pop(context, SuggestionAction.createNew),
        child: const Text('Create New'),
      ),
    );

    return actions;
  }
}

/// Simple detail row widget
class _SongDetailRow extends StatelessWidget {

  const _SongDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Action returned by dialog
enum SuggestionAction {
  /// Use existing song (link to it)
  useExisting,

  /// Fork group song to personal
  fork,

  /// Create new song
  createNew,
}
