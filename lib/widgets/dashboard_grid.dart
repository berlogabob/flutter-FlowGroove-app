import 'dart:io';

import 'package:flutter/material.dart';
import '../theme/mono_pulse_theme.dart';

/// Dashboard grid displaying statistics and quick actions.
///
/// Features:
/// - Responsive grid layout with automatic wrapping
/// - Stat cards with icons, labels, and values
/// - Quick action buttons
/// - Tool buttons with "Soon" badges
///
/// Usage:
/// ```dart
/// DashboardGrid(
///   greetingCard: GreetingCard(userName: 'John'),
///   statistics: [
///     StatCard(icon: Icons.music_note, label: 'Songs', value: '42', ...),
///     StatCard(icon: Icons.groups, label: 'Bands', value: '3', ...),
///   ],
///   quickActions: [
///     QuickActionButton(icon: Icons.add, label: 'Song', ...),
///   ],
///   tools: [
///     ToolButton(icon: Icons.tune, label: 'Tuner', ...),
///   ],
/// )
/// ```
class DashboardGrid extends StatelessWidget {
  /// Greeting card widget (optional).
  final Widget? greetingCard;

  /// List of statistics cards.
  final List<StatCard> statistics;

  /// List of quick action buttons.
  final List<QuickActionButton> quickActions;

  /// List of tool buttons.
  final List<ToolButton> tools;

  const DashboardGrid({
    super.key,
    required this.statistics,
    required this.quickActions,
    required this.tools,
    this.greetingCard,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(MonoPulseSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting card
          if (greetingCard != null) ...[
            greetingCard!,
            const SizedBox(height: MonoPulseSpacing.xxxl),
          ],

          // Statistics section
          if (statistics.isNotEmpty) ...[
            _buildSectionTitle(context, 'My Library'),
            const SizedBox(height: MonoPulseSpacing.md),
            _buildStatisticsGrid(context),
            const SizedBox(height: MonoPulseSpacing.xxxl),
          ],

          // Quick actions section
          if (quickActions.isNotEmpty) ...[
            _buildSectionTitle(context, 'Quick Actions'),
            const SizedBox(height: MonoPulseSpacing.md),
            _buildQuickActionsGrid(context),
            const SizedBox(height: MonoPulseSpacing.xxxl),
          ],

          // Tools section
          if (tools.isNotEmpty) ...[
            _buildSectionTitle(context, 'Tools'),
            const SizedBox(height: MonoPulseSpacing.md),
            _buildToolsGrid(context),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: MonoPulseColors.textPrimary,
      ),
    );
  }

  Widget _buildStatisticsGrid(BuildContext context) {
    return _buildFixedGrid(
      children: statistics.map((stat) => stat).toList(),
      crossAxisCount: 3,
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    // Always 2 columns for 2x2 layout with 4 quick actions
    return _buildFixedGrid(
      children: quickActions.map((action) => action).toList(),
      crossAxisCount: 2,
    );
  }

  Widget _buildToolsGrid(BuildContext context) {
    // 2 columns for future 2x2 layout support
    return _buildFixedGrid(
      children: tools.map((tool) => tool).toList(),
      crossAxisCount: 2,
    );
  }

  /// Builds a fixed grid with specified number of columns using GridView.
  Widget _buildFixedGrid({
    required List<Widget> children,
    required int crossAxisCount,
  }) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: MonoPulseSpacing.md,
        mainAxisSpacing: MonoPulseSpacing.md,
        childAspectRatio: 2.8,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }

}

/// Statistics card displaying an icon, value, and label.
class StatCard extends StatelessWidget {
  /// Icon to display.
  final IconData icon;

  /// Label text.
  final String label;

  /// Value text (the statistic).
  final String value;

  /// Icon color.
  final Color color;

  /// Callback when card is tapped (optional).
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: MonoPulseSpacing.lg,
          vertical: MonoPulseSpacing.md,
        ),
        decoration: BoxDecoration(
          color: MonoPulseColors.surface,
          borderRadius: BorderRadius.circular(MonoPulseRadius.large),
          border: Border.all(color: MonoPulseColors.borderSubtle),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: MonoPulseSpacing.sm),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: MonoPulseColors.textTertiary,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick action button for dashboard.
///
/// Uses a vertical layout (icon above text) for better space utilization
/// on narrow screens and to prevent overflow issues.
class QuickActionButton extends StatelessWidget {
  /// Icon to display.
  final IconData icon;

  /// Label text.
  final String label;

  /// Callback when button is pressed.
  final VoidCallback onTap;

  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MonoPulseColors.surface,
      borderRadius: BorderRadius.circular(MonoPulseRadius.large),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MonoPulseRadius.large),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MonoPulseSpacing.lg,
            vertical: MonoPulseSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: MonoPulseColors.surface,
            border: Border.all(color: MonoPulseColors.borderDefault),
            borderRadius: BorderRadius.circular(MonoPulseRadius.large),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: MonoPulseColors.accentOrange, size: 24),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: MonoPulseColors.accentOrange,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tool button for dashboard (may be disabled with "Soon" badge).
///
/// Uses a vertical layout (icon above text) for better space utilization
/// on narrow screens and to prevent overflow issues.
class ToolButton extends StatelessWidget {
  /// Icon to display.
  final IconData icon;

  /// Label text.
  final String label;

  /// Callback when button is pressed (null = disabled).
  final VoidCallback? onTap;

  const ToolButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: MonoPulseSpacing.lg,
          vertical: MonoPulseSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isEnabled
              ? MonoPulseColors.surface
              : MonoPulseColors.surfaceOverlay,
          borderRadius: BorderRadius.circular(MonoPulseRadius.large),
          border: Border.all(color: MonoPulseColors.borderSubtle),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isEnabled
                  ? MonoPulseColors.accentOrange
                  : MonoPulseColors.textTertiary,
              size: 24,
            ),
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: isEnabled
                      ? MonoPulseColors.accentOrange
                      : MonoPulseColors.textTertiary,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!isEnabled) ...[
              const SizedBox(height: MonoPulseSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MonoPulseSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: MonoPulseColors.borderStrong,
                  borderRadius: BorderRadius.circular(MonoPulseRadius.small),
                ),
                child: Text(
                  'Soon',
                  style: MonoPulseTypography.labelSmall.copyWith(
                    color: MonoPulseColors.textPrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Greeting card widget for dashboard.
class GreetingCard extends StatelessWidget {
  /// User name to display.
  final String userName;

  /// User avatar URL or path (optional).
  final String? avatarPath;

  /// Subtitle text (optional).
  final String? subtitle;

  const GreetingCard({
    super.key,
    required this.userName,
    this.avatarPath,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return Container(
      padding: const EdgeInsets.all(MonoPulseSpacing.lg),
      decoration: BoxDecoration(
        color: MonoPulseColors.accentOrangeSubtle,
        borderRadius: BorderRadius.circular(MonoPulseRadius.large),
        border: Border.all(color: MonoPulseColors.borderSubtle),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: MonoPulseColors.surfaceRaised,
            // Try to load from URL first, then from file, then show initial
            backgroundImage: avatarPath != null && avatarPath!.isNotEmpty
                ? (avatarPath!.startsWith('http')
                      ? NetworkImage(avatarPath!) as ImageProvider
                      : FileImage(File(avatarPath!)))
                : null,
            child: avatarPath == null || avatarPath!.isEmpty
                ? Text(
                    initial,
                    style: MonoPulseTypography.headlineSmall.copyWith(
                      color: MonoPulseColors.accentOrange,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: MonoPulseSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'Hello, $userName!',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: MonoPulseColors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Flexible(
                  child: Text(
                    subtitle ?? 'Ready to rock?',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: MonoPulseColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
