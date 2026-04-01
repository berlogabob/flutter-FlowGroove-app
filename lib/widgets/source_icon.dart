import 'package:flutter/material.dart';
import '../models/song_suggestion.dart';
import '../theme/mono_pulse_theme.dart';

/// Source icon for song suggestions
/// 
/// Displays different icons and colors based on suggestion source:
/// - Personal: Person icon (orange)
/// - Group: Group icon (blue)
/// - MusicBrainz: Cloud icon (green)
/// - Canonical: Library icon (purple)
/// 
/// Usage:
/// ```dart
/// SourceIcon(source: SuggestionSource.personal)
/// ```
class SourceIcon extends StatelessWidget {
  final SuggestionSource source;
  final double size;

  const SourceIcon({
    super.key,
    required this.source,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    final iconData = _getIcon();
    final color = _getColor(context);

    return Container(
      width: size + 8,
      height: size + 8,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        size: size,
        color: color,
      ),
    );
  }

  IconData _getIcon() {
    switch (source) {
      case SuggestionSource.personal:
        return Icons.person;
      case SuggestionSource.group:
        return Icons.group;
      case SuggestionSource.musicbrainz:
        return Icons.cloud;
      case SuggestionSource.canonical:
        return Icons.library_music;
    }
  }

  Color _getColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    switch (source) {
      case SuggestionSource.personal:
        return colorScheme.primary;
      case SuggestionSource.group:
        return colorScheme.secondary;
      case SuggestionSource.musicbrainz:
        return MonoPulseColors.successGreen;
      case SuggestionSource.canonical:
        return colorScheme.tertiary;
    }
  }
}
