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
        fontWeight: FontWeight.bold,
        color: MonoPulseColors.textPrimary,
      ),
    );
  }

  Widget _buildStatisticsGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        
        // Responsive column count based on available width
        final columns = screenWidth < 400
            ? 1
            : screenWidth < 700
                ? 2
                : 3;

        return _buildResponsiveGrid(
          children: statistics.map((stat) => stat).toList(),
          columns: columns,
        );
      },
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;

        // Responsive column count for quick actions
        // Always use 2 columns on phones for 2x2 layout with 4 actions
        final columns = screenWidth < 350
            ? 1
            : 2;

        return _buildResponsiveGrid(
          children: quickActions.map((action) => action).toList(),
          columns: columns,
        );
      },
    );
  }

  Widget _buildToolsGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;

        // Tools use 2 columns on most screens for 2x2 layout support
        // 1 column only on very narrow screens
        final columns = screenWidth < 350 ? 1 : 2;

        return _buildResponsiveGrid(
          children: tools.map((tool) => tool).toList(),
          columns: columns,
        );
      },
    );
  }

  /// Builds a responsive grid with specified number of columns.
  /// Uses Wrap widget for automatic wrapping and proper spacing.
  Widget _buildResponsiveGrid({
    required List<Widget> children,
    required int columns,
  }) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final itemWidth = (availableWidth - (MonoPulseSpacing.md * (columns - 1))) / columns;

        return Wrap(
          spacing: MonoPulseSpacing.md,
          runSpacing: MonoPulseSpacing.md,
          children: children.map((child) {
            return SizedBox(
              width: itemWidth,
              child: child,
            );
          }).toList(),
        );
      },
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
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        decoration: BoxDecoration(
          color: MonoPulseColors.surface,
          borderRadius: BorderRadius.circular(MonoPulseRadius.large),
          border: Border.all(color: MonoPulseColors.borderSubtle),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: MonoPulseSpacing.md),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: MonoPulseColors.textTertiary,
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
          padding: const EdgeInsets.all(MonoPulseSpacing.lg),
          decoration: BoxDecoration(
            color: MonoPulseColors.surface,
            border: Border.all(color: MonoPulseColors.borderDefault),
            borderRadius: BorderRadius.circular(MonoPulseRadius.large),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: MonoPulseColors.accentOrange, size: 28),
              const SizedBox(height: MonoPulseSpacing.sm),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: MonoPulseColors.accentOrange,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
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
            ),
            const SizedBox(height: MonoPulseSpacing.sm),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: isEnabled
                    ? MonoPulseColors.accentOrange
                    : MonoPulseColors.textTertiary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
            radius: 30,
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
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: MonoPulseSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $userName!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: MonoPulseColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle ?? 'Ready to rock?',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MonoPulseColors.textTertiary,
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
