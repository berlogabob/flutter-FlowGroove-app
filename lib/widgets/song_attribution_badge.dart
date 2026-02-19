import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A badge widget showing song attribution information.
///
/// This widget displays badges indicating:
/// - Original owner (who created the song)
/// - Contributor (who added it to the band)
/// - Copy indicator (if this is a band's copy of a personal song)
class SongAttributionBadge extends StatelessWidget {
  /// The display name of the original owner.
  final String? originalOwnerName;

  /// The display name of the contributor.
  final String? contributorName;

  /// Whether this song is a copy (shared from personal to band).
  final bool isCopy;

  /// The size of the badge.
  final BadgeSize size;

  /// Whether to show the original owner badge.
  final bool showOriginalOwner;

  /// Whether to show the contributor badge.
  final bool showContributor;

  /// Whether to show the copy indicator.
  final bool showCopyIndicator;

  const SongAttributionBadge({
    super.key,
    this.originalOwnerName,
    this.contributorName,
    this.isCopy = false,
    this.size = BadgeSize.small,
    this.showOriginalOwner = true,
    this.showContributor = true,
    this.showCopyIndicator = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showOriginalOwner && !showContributor && !showCopyIndicator) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: _spacing,
      runSpacing: 4,
      children: [
        if (showCopyIndicator && isCopy) _buildCopyBadge(),
        if (showOriginalOwner && originalOwnerName != null)
          _buildOriginalOwnerBadge(),
        if (showContributor && contributorName != null && isCopy)
          _buildContributorBadge(),
      ],
    );
  }

  Widget _buildCopyBadge() {
    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: AppColors.color5.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(_borderRadius),
        border: Border.all(color: AppColors.color5, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.content_copy, size: _iconSize, color: AppColors.color5),
          if (_showLabels) ...[
            const SizedBox(width: 4),
            Text(
              'Shared',
              style: TextStyle(
                color: AppColors.color5,
                fontSize: _textSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOriginalOwnerBadge() {
    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: AppColors.color1.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(_borderRadius),
        border: Border.all(color: AppColors.color1, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person, size: _iconSize, color: AppColors.color1),
          if (_showLabels) ...[
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'by $originalOwnerName',
                style: TextStyle(
                  color: AppColors.color1,
                  fontSize: _textSize,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContributorBadge() {
    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: AppColors.color3.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(_borderRadius),
        border: Border.all(color: AppColors.color3, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_circle_outline,
            size: _iconSize,
            color: AppColors.color4,
          ),
          if (_showLabels) ...[
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'added by $contributorName',
                style: TextStyle(
                  color: AppColors.color4,
                  fontSize: _textSize,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool get _showLabels => size == BadgeSize.medium || size == BadgeSize.large;

  double get _iconSize {
    switch (size) {
      case BadgeSize.small:
        return 12;
      case BadgeSize.medium:
        return 14;
      case BadgeSize.large:
        return 16;
    }
  }

  double get _textSize {
    switch (size) {
      case BadgeSize.small:
        return 10;
      case BadgeSize.medium:
        return 11;
      case BadgeSize.large:
        return 12;
    }
  }

  EdgeInsets get _padding {
    switch (size) {
      case BadgeSize.small:
        return const EdgeInsets.symmetric(horizontal: 6, vertical: 2);
      case BadgeSize.medium:
        return const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
      case BadgeSize.large:
        return const EdgeInsets.symmetric(horizontal: 10, vertical: 6);
    }
  }

  double get _borderRadius {
    switch (size) {
      case BadgeSize.small:
        return 4;
      case BadgeSize.medium:
        return 6;
      case BadgeSize.large:
        return 8;
    }
  }

  double get _spacing {
    switch (size) {
      case BadgeSize.small:
        return 4;
      case BadgeSize.medium:
        return 6;
      case BadgeSize.large:
        return 8;
    }
  }
}

/// A compact attribution badge for use in list items.
class CompactAttributionBadge extends StatelessWidget {
  /// Whether this is a copy.
  final bool isCopy;

  /// The contributor name.
  final String? contributorName;

  const CompactAttributionBadge({
    super.key,
    required this.isCopy,
    this.contributorName,
  });

  @override
  Widget build(BuildContext context) {
    if (!isCopy) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.color5.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.content_copy, size: 12, color: AppColors.color5),
          if (contributorName != null) ...[
            const SizedBox(width: 4),
            Text(
              'by $contributorName',
              style: const TextStyle(
                color: AppColors.color5,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Badge size options.
enum BadgeSize {
  /// Small badge for compact spaces.
  small,

  /// Medium badge with labels.
  medium,

  /// Large badge with full details.
  large,
}

/// A widget that displays attribution information in a ListTile subtitle.
class AttributionSubtitle extends StatelessWidget {
  /// The primary subtitle text (e.g., artist name).
  final String subtitle;

  /// The original owner name.
  final String? originalOwnerName;

  /// The contributor name.
  final String? contributorName;

  /// Whether this is a copy.
  final bool isCopy;

  const AttributionSubtitle({
    super.key,
    required this.subtitle,
    this.originalOwnerName,
    this.contributorName,
    this.isCopy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        SongAttributionBadge(
          originalOwnerName: originalOwnerName,
          contributorName: contributorName,
          isCopy: isCopy,
          size: BadgeSize.small,
          showOriginalOwner: false, // Hide in compact view
          showContributor: true,
          showCopyIndicator: true,
        ),
      ],
    );
  }
}
