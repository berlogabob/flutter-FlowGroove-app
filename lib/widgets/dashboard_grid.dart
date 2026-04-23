import 'package:flutter/material.dart';

import '../theme/mono_pulse_theme.dart';
import '../utils/responsive_breakpoints.dart';
import 'stat_card.dart';
import 'quick_action_button.dart';
import 'tool_button.dart';

/// Dashboard grid displaying statistics and quick actions.
///
/// Responsive design adapts layout based on screen breakpoint:
/// - Mobile (< 600px): Single column, full-width cards
/// - Tablet (600-1024px): 2-column grid
/// - Desktop (> 1024px): 3-column grid
///
/// Features:
/// - Responsive grid layout with automatic breakpoint detection
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final breakpoint = getBreakpoint(constraints.maxWidth);
        final padding = _getPaddingForBreakpoint(breakpoint);
        final sectionSpacing = _getSectionSpacing(breakpoint);

        return SingleChildScrollView(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting card
              if (greetingCard != null) ...[
                greetingCard!,
                SizedBox(height: sectionSpacing),
              ],

              // Statistics section
              if (statistics.isNotEmpty) ...[
                _buildSectionTitle(context, 'My Library', breakpoint),
                SizedBox(height: MonoPulseSpacing.md),
                _buildResponsiveStatisticsGrid(breakpoint),
                SizedBox(height: sectionSpacing),
              ],

              // Quick actions section
              if (quickActions.isNotEmpty) ...[
                _buildSectionTitle(context, 'Quick Actions', breakpoint),
                SizedBox(height: MonoPulseSpacing.md),
                _buildResponsiveQuickActionsGrid(breakpoint),
                SizedBox(height: sectionSpacing),
              ],

              // Tools section
              if (tools.isNotEmpty) ...[
                _buildSectionTitle(context, 'Tools', breakpoint),
                SizedBox(height: MonoPulseSpacing.md),
                _buildResponsiveToolsGrid(breakpoint, constraints.maxWidth),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Get padding based on breakpoint.
  EdgeInsets _getPaddingForBreakpoint(ScreenBreakpoint breakpoint) {
    switch (breakpoint) {
      case ScreenBreakpoint.mobile:
        return const EdgeInsets.all(MonoPulseSpacing.lg);
      case ScreenBreakpoint.tablet:
        return const EdgeInsets.all(MonoPulseSpacing.xl);
      case ScreenBreakpoint.desktop:
        return const EdgeInsets.all(MonoPulseSpacing.xxl);
    }
  }

  /// Get section spacing based on breakpoint.
  double _getSectionSpacing(ScreenBreakpoint breakpoint) {
    switch (breakpoint) {
      case ScreenBreakpoint.mobile:
        return MonoPulseSpacing.xxxl;
      case ScreenBreakpoint.tablet:
        return MonoPulseSpacing.xxxl + 8;
      case ScreenBreakpoint.desktop:
        return MonoPulseSpacing.xxxl + 16;
    }
  }

  Widget _buildSectionTitle(
    BuildContext context,
    String title,
    ScreenBreakpoint breakpoint,
  ) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: MonoPulseColors.textPrimary,
        fontSize: breakpoint == ScreenBreakpoint.desktop ? 18 : 16,
      ),
    );
  }

  Widget _buildResponsiveStatisticsGrid(ScreenBreakpoint breakpoint) {
    // Always 3 columns for statistics (Songs, Bands, Setlists in 1 row)
    return _buildFixedGrid(
      children: statistics,
      crossAxisCount: 3,
      aspectRatio: ResponsiveSizes.statCardAspectRatio(breakpoint),
    );
  }

  Widget _buildResponsiveQuickActionsGrid(ScreenBreakpoint breakpoint) {
    // Mobile: 2 columns, Tablet/Desktop: 4 columns (2x2 grid)
    final crossAxisCount = breakpoint == ScreenBreakpoint.mobile ? 2 : 4;
    return _buildFixedGrid(
      children: quickActions,
      crossAxisCount: crossAxisCount,
    );
  }

  Widget _buildResponsiveToolsGrid(
    ScreenBreakpoint breakpoint,
    double maxWidth,
  ) {
    // Mobile: 2 columns (Tuner, Metronome side by side)
    // Tablet/Desktop: 2 columns with more tools in 2nd row
    final crossAxisCount = 2;

    return _buildFixedGrid(
      children: tools,
      crossAxisCount: crossAxisCount,
    );
  }

  /// Builds a responsive grid with specified number of columns using GridView.
  Widget _buildFixedGrid({
    required List<Widget> children,
    required int crossAxisCount,
    double? aspectRatio,
  }) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final breakpoint = getBreakpoint(constraints.maxWidth);
        final gridAspectRatio = aspectRatio ?? ResponsiveSizes.cardAspectRatio(breakpoint);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: MonoPulseSpacing.md,
            mainAxisSpacing: MonoPulseSpacing.md,
            childAspectRatio: gridAspectRatio,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => FittedBox(
            fit: BoxFit.contain,
            child: children[index],
          ),
        );
      },
    );
  }
}
