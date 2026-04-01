import 'package:flutter/material.dart';
import '../theme/mono_pulse_theme.dart';

/// Match score badge for song suggestions
/// 
/// Displays match confidence as a colored percentage:
/// - 90-100%: Green (Exact match)
/// - 75-89%: Yellow/Orange (Close match)
/// - 60-74%: Orange (Similar)
/// - <60%: Red or hidden (Weak match)
/// 
/// Usage:
/// ```dart
/// MatchScoreBadge(score: 0.95) // Shows "95%" in green
/// ```
class MatchScoreBadge extends StatelessWidget {
  final double score;
  final double size;
  final bool showLabel;

  const MatchScoreBadge({
    super.key,
    required this.score,
    this.size = 36,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    // Don't show badge for perfect matches (already obvious)
    if (score >= 1.0 && !showLabel) return const SizedBox.shrink();

    final color = _getColor();
    final label = _getLabel();

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLabel)
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          if (!showLabel)
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  Color _getColor() {
    if (score >= 0.90) {
      return MonoPulseColors.matchExact;
    } else if (score >= 0.75) {
      return MonoPulseColors.matchMedium;
    } else if (score >= 0.60) {
      return MonoPulseColors.matchLow;
    } else {
      return MonoPulseColors.matchNone;
    }
  }

  String _getLabel() {
    final percentage = (score * 100).round();
    return '$percentage%';
  }
}

/// Simple dot indicator for match quality
class MatchQualityDot extends StatelessWidget {
  final double score;
  final double size;

  const MatchQualityDot({
    super.key,
    required this.score,
    this.size = 8,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getColor();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Color _getColor() {
    if (score >= 0.90) {
      return MonoPulseColors.matchExact;
    } else if (score >= 0.75) {
      return MonoPulseColors.matchMedium;
    } else if (score >= 0.60) {
      return MonoPulseColors.matchLow;
    } else {
      return MonoPulseColors.matchNone;
    }
  }
}
