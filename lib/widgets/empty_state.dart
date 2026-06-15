import 'package:flutter/material.dart';
import '../theme/mono_pulse_theme.dart';

/// A widget for displaying an empty state message.
///
/// This widget provides a consistent empty state layout for when there
/// is no data to display, with an optional call-to-action button.
class EmptyState extends StatelessWidget {
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

  /// The color of the icon.
  final Color? iconColor;

  /// The size of the icon.
  final double iconSize;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.iconSize = 80,
    this.hint,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: message,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              excludeSemantics: true,
              child: Icon(
                icon,
                size: iconSize,
                color: iconColor ?? MonoPulseColors.textTertiary,
              ),
            ),
            SizedBox(height: MonoPulseSpacing.lg),
            Text(
              message,
              style: MonoPulseTypography.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (hint != null) ...[
              SizedBox(height: MonoPulseSpacing.sm),
              Text(
                hint!,
                style: MonoPulseTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: MonoPulseSpacing.xxl),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }

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
  factory EmptyState.bands({VoidCallback? onCreate}) {
    return EmptyState(
      icon: Icons.groups,
      message: 'No bands yet',
      hint: 'Create a band to get started',
      actionLabel: 'Create Band',
      onAction: onCreate,
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
}
