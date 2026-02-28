import 'package:flutter/material.dart';
import '../theme/mono_pulse_theme.dart';

/// Dashboard grid displaying statistics and quick actions.
///
/// Features:
/// - Responsive grid layout
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
    this.greetingCard,
    required this.statistics,
    required this.quickActions,
    required this.tools,
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
    return Row(
      children: statistics.map((stat) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: stat == statistics.last ? 0 : MonoPulseSpacing.md,
            ),
            child: stat,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    return Column(
      children: [
        // First row
        Row(
          children: quickActions.take(2).map((action) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right:
                      quickActions.indexOf(action) % 2 == 0 &&
                          quickActions.indexOf(action) < quickActions.length - 1
                      ? MonoPulseSpacing.md
                      : 0,
                ),
                child: action,
              ),
            );
          }).toList(),
        ),
        // Second row (if more than 2 actions)
        if (quickActions.length > 2)
          Row(
            children: quickActions.skip(2).take(2).map((action) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right:
                        quickActions.indexOf(action) % 2 == 0 &&
                            quickActions.indexOf(action) <
                                quickActions.length - 1
                        ? MonoPulseSpacing.md
                        : 0,
                  ),
                  child: action,
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildToolsGrid(BuildContext context) {
    return Row(
      children: tools.map((tool) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: tool == tools.last ? 0 : MonoPulseSpacing.md,
            ),
            child: tool,
          ),
        );
      }).toList(),
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
          padding: const EdgeInsets.symmetric(vertical: MonoPulseSpacing.xxl),
          decoration: BoxDecoration(
            color: MonoPulseColors.surface,
            border: Border.all(color: MonoPulseColors.borderDefault),
            borderRadius: BorderRadius.circular(MonoPulseRadius.large),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: MonoPulseColors.accentOrange),
              const SizedBox(width: MonoPulseSpacing.md),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: MonoPulseColors.accentOrange,
                  fontWeight: FontWeight.w600,
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
        padding: const EdgeInsets.symmetric(vertical: MonoPulseSpacing.xxl),
        decoration: BoxDecoration(
          color: isEnabled
              ? MonoPulseColors.surface
              : MonoPulseColors.surfaceOverlay,
          borderRadius: BorderRadius.circular(MonoPulseRadius.large),
          border: Border.all(color: MonoPulseColors.borderSubtle),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isEnabled
                  ? MonoPulseColors.accentOrange
                  : MonoPulseColors.textTertiary,
            ),
            const SizedBox(width: MonoPulseSpacing.md),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: isEnabled
                    ? MonoPulseColors.accentOrange
                    : MonoPulseColors.textTertiary,
              ),
            ),
            if (!isEnabled) ...[
              const SizedBox(width: MonoPulseSpacing.sm),
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: MonoPulseColors.textPrimary,
                    fontSize: 10,
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
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 24,
                color: MonoPulseColors.accentOrange,
                fontWeight: FontWeight.bold,
              ),
            ),
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
