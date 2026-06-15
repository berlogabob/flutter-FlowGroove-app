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
  const MatchScoreBadge({
    super.key,
    required this.score,
    this.showLabel = true,
    this.size = 40, // MonoPulseSpacing.xxxl equivalent for badge container
  });

  final double score;
  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    // Don't show badge for perfect matches (already obvious)
    if (score >= 1.0 && !showLabel) return const SizedBox.shrink();

    final color = _getColor();
    final label = _getLabel();

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.symmetric(
        horizontal: MonoPulseSpacing.xs,
        vertical: 4, // Custom micro-padding for tight badge layout
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(MonoPulseRadius.small),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: MonoPulseBorder.thin,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLabel)
            Text(
              label,
              style: TextStyle(
                fontSize: 10, // Micro label for badge
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          if (!showLabel)
            Container(
              width: 8, // Micro dot indicator
              height: 8,
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
