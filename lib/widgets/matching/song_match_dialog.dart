/// Match confirmation dialog widget.
///
/// Shows a dialog when a potential song match is found,
/// allowing the user to confirm or decline the match.
library;

import 'package:flutter/material.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../services/matching/match_scorer.dart';

/// Dialog for confirming song matches.
class SongMatchDialog extends StatelessWidget {
  /// The match score to display.
  final MatchScore matchScore;

  /// The user's original input.
  final String userInput;

  const SongMatchDialog({
    super.key,
    required this.matchScore,
    required this.userInput,
  });

  /// Shows the match dialog and returns true if user accepts the match.
  static Future<bool?> show(
    BuildContext context, {
    required MatchScore match,
    required String userInput,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) =>
          SongMatchDialog(matchScore: match, userInput: userInput),
    );
  }

  @override
  Widget build(BuildContext context) {
    final song = matchScore.matchedSong;
    final confidence = matchScore.total;
    final grade = matchScore.grade;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(_getGradeIcon(grade), color: _getGradeColor(grade)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _getGradeTitle(grade),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'We found a similar song in your library:',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),

          // Matched song card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getGradeColor(grade).withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  song.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Artist
                Row(
                  children: [
                    Icon(
                      Icons.person,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        song.artist,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // Album (if available)
                if (song.album != null && song.album!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.album,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          song.album!,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                // Duration (if available)
                if (song.durationMs != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.timer,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(song.durationMs!),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                // Confidence badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getGradeColor(grade).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getGradeColor(grade).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        size: 14,
                        color: _getGradeColor(grade),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${confidence.toStringAsFixed(0)}% Match',
                        style: TextStyle(
                          color: _getGradeColor(grade),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // User input comparison
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your input:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '"$userInput"',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),

          // Differences (if not exact match)
          if (confidence < 98) ...[
            const SizedBox(height: 16),
            Text(
              'Differences detected:',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._buildDifferencesList(context, matchScore),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Create New'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.check),
          label: Text(confidence >= 98 ? 'Use Match' : 'Use Existing'),
        ),
      ],
    );
  }

  IconData _getGradeIcon(MatchGrade grade) {
    switch (grade) {
      case MatchGrade.exact:
        return Icons.check_circle;
      case MatchGrade.high:
        return Icons.thumb_up;
      case MatchGrade.medium:
        return Icons.info_outline;
      case MatchGrade.low:
        return Icons.help_outline;
      case MatchGrade.none:
        return Icons.block;
    }
  }

  Color _getGradeColor(MatchGrade grade) {
    switch (grade) {
      case MatchGrade.exact:
        return MonoPulseColors.matchExact;
      case MatchGrade.high:
        return MonoPulseColors.matchHigh;
      case MatchGrade.medium:
        return MonoPulseColors.matchMedium;
      case MatchGrade.low:
        return MonoPulseColors.matchLow;
      case MatchGrade.none:
        return MonoPulseColors.matchNone;
    }
  }

  String _getGradeTitle(MatchGrade grade) {
    switch (grade) {
      case MatchGrade.exact:
        return 'Exact Match Found';
      case MatchGrade.high:
        return 'Strong Match Found';
      case MatchGrade.medium:
        return 'Possible Match Found';
      case MatchGrade.low:
        return 'Weak Match Found';
      case MatchGrade.none:
        return 'No Match';
    }
  }

  String _formatDuration(int ms) {
    final minutes = ms ~/ 60000;
    final seconds = ((ms % 60000) / 1000).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  List<Widget> _buildDifferencesList(BuildContext context, MatchScore score) {
    final differences = <Widget>[];

    if (score.titleSimilarity < 95) {
      differences.add(
        Row(
          children: [
            const Icon(Icons.edit, size: 14, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              'Title spelling variation',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    if (score.artistSimilarity < 90) {
      differences.add(
        Row(
          children: [
            const Icon(Icons.person_outline, size: 14, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              'Artist name variation',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    if (score.durationSimilarity > 0 && score.durationSimilarity < 80) {
      differences.add(
        Row(
          children: [
            const Icon(Icons.timer_outlined, size: 14, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              'Duration difference',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return differences;
  }
}
