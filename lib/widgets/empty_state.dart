import 'package:flutter/material.dart';
import '../theme/mono_pulse_theme.dart';

/// A widget for displaying an empty state message.
///
/// This widget provides a consistent empty state layout for when there
/// is no data to display, with an optional call-to-action button.
class EmptyState extends StatelessWidget {

  const EmptyState({
    required this.icon,
    required this.message,
    this.hint,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.iconColor,
    this.iconSize = 80,
    super.key,
  });

  /// Create an empty state for songs.
  factory EmptyState.songs({VoidCallback? onAdd}) {
    return EmptyState(
      icon: Icons.music_note,
      message: 'No songs yet',
      hint: 'Tap + to add your first song',
      actionLabel: 'Add Song',
      onAction: onAdd,
    );
  }

  /// Create an empty state for bands.
  factory EmptyState.bands({VoidCallback? onCreate, VoidCallback? onJoin}) {
    return EmptyState(
      icon: Icons.groups,
      message: 'No bands yet',
      hint: 'Create a band to get started',
      actionLabel: 'Create Band',
      onAction: onCreate,
      secondaryActionLabel: 'Join band',
      onSecondaryAction: onJoin,
    );
  }

  /// Create an empty state for setlists.
  factory EmptyState.setlists({VoidCallback? onCreate}) {
    return EmptyState(
      icon: Icons.playlist_play,
      message: 'No setlists yet',
      hint: 'Create a setlist for your next gig',
      actionLabel: 'Create Setlist',
      onAction: onCreate,
    );
  }

  /// Create an empty state for search results.
  factory EmptyState.search({String? query}) {
    return EmptyState(
      icon: Icons.search_off,
      message: 'No results found',
      hint: query != null
          ? 'Try searching for "$query"'
          : 'Try different keywords',
    );
  }
  /// The icon to display.
  final IconData icon;

  /// The main message to display.
  final String message;

  /// A secondary hint message.
  final String? hint;

  /// The label for the action button.
  final String? actionLabel;

  /// Callback when the action button is pressed.
  final VoidCallback? onAction;

  final String? secondaryActionLabel;

  final VoidCallback? onSecondaryAction;

  /// The color of the icon.
  final Color? iconColor;

  /// The size of the icon.
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: iconSize,
            color: iconColor ?? MonoPulseColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: MonoPulseTypography.headlineSmall,
            textAlign: TextAlign.center,
          ),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(
              hint!,
              style: MonoPulseTypography.bodyMedium.copyWith(
                color: MonoPulseColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionLabel!),
            ),
          ],
          if (secondaryActionLabel != null && onSecondaryAction != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onSecondaryAction,
              icon: const Icon(Icons.group_add),
              label: Text(secondaryActionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
