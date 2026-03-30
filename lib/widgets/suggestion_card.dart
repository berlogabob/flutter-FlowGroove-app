import 'package:flutter/material.dart';
import '../theme/mono_pulse_theme.dart';
import '../models/song_suggestion.dart';
import 'source_icon.dart';
import 'match_score_badge.dart';

/// Suggestion card widget for autocomplete dropdown
/// 
/// Displays a song suggestion with:
/// - Source icon (personal/group/MusicBrainz)
/// - Title and artist
/// - Match score badge
/// - Additional info (BPM, key, album)
/// - Forkable indicator for group songs
/// 
/// Usage:
/// ```dart
/// SuggestionCard(
///   suggestion: suggestion,
///   isSelected: true,
///   onTap: () => print('Selected!'),
/// )
/// ```
class SuggestionCard extends StatelessWidget {
  final SongSuggestion suggestion;
  final bool isSelected;
  final VoidCallback onTap;

  const SuggestionCard({
    super.key,
    required this.suggestion,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      hoverColor: colorScheme.primary.withValues(alpha: 0.04),
      highlightColor: colorScheme.primary.withValues(alpha: 0.08),
      child: Container(
        padding: const EdgeInsets.all(MonoPulseSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main row: icon, title, score
            Row(
              children: [
                // Source icon
                SourceIcon(source: suggestion.source),
                
                const SizedBox(width: 10),
                
                // Title
                Expanded(
                  child: Text(
                    suggestion.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Match score badge
                MatchScoreBadge(score: suggestion.matchScore),
              ],
            ),
            
            const SizedBox(height: 4),
            
            // Second row: artist and metadata
            Row(
              children: [
                // Artist
                Expanded(
                  child: Text(
                    suggestion.artist,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            // Third row: badges and metadata
            if (_hasMetadata) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _buildBadges(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool get _hasMetadata {
    return suggestion.bpm != null ||
        suggestion.key != null ||
        suggestion.album != null ||
        suggestion.isForkable ||
        suggestion.bandName != null;
  }

  List<Widget> _buildBadges(BuildContext context) {
    final badges = <Widget>[];
    final theme = Theme.of(context);

    // Band badge (for group songs)
    if (suggestion.bandName != null) {
      badges.add(
        _Badge(
          label: suggestion.bandName!,
          icon: Icons.group,
          color: theme.colorScheme.primary,
        ),
      );
    }

    // Forkable badge
    if (suggestion.isForkable) {
      badges.add(
        _Badge(
          label: 'Fork',
          icon: Icons.call_split,
          color: theme.colorScheme.tertiary,
          tooltip: 'Create your own version',
        ),
      );
    }

    // BPM badge
    if (suggestion.bpm != null) {
      badges.add(
        _Badge(
          label: '${suggestion.bpm} BPM',
          icon: Icons.speed,
          color: theme.colorScheme.secondary,
        ),
      );
    }

    // Key badge
    if (suggestion.key != null) {
      badges.add(
        _Badge(
          label: 'Key: ${suggestion.key}',
          icon: Icons.music_note,
          color: theme.colorScheme.tertiary,
        ),
      );
    }

    // Album/year badge
    if (suggestion.album != null || suggestion.releaseYear != null) {
      final albumText = [
        if (suggestion.album != null) suggestion.album,
        if (suggestion.releaseYear != null) suggestion.releaseYear.toString(),
      ].join(' • ');
      
      badges.add(
        _Badge(
          label: albumText,
          icon: Icons.album,
          color: theme.colorScheme.outline,
          opacity: 0.7,
        ),
      );
    }

    return badges;
  }
}

/// Small badge chip
class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final double? opacity;
  final String? tooltip;

  const _Badge({
    required this.label,
    required this.icon,
    required this.color,
    this.opacity,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(MonoPulseRadius.small),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color.withValues(alpha: opacity ?? 1.0),
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color.withValues(alpha: opacity ?? 1.0),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    return tooltip != null
        ? Tooltip(message: tooltip!, child: badge)
        : badge;
  }
}
