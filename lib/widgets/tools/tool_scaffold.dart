import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../widgets/offline_indicator.dart';
import '../../widgets/custom_app_bar.dart';

/// Responsive breakpoint system for tool screens.
enum ToolBreakpoint {
  compact, // < 375px (small phones)
  medium, // 375-599px (standard phones)
  expanded, // 600-1023px (tablets)
  desktop; // >= 1024px (desktop)

  static ToolBreakpoint fromWidth(double width) {
    if (width < 375) return compact;
    if (width < 600) return medium;
    if (width < 1024) return expanded;
    return desktop;
  }

  static ToolBreakpoint of(BuildContext context) {
    return fromWidth(MediaQuery.of(context).size.width);
  }
}

/// Spacing values adapted to breakpoint.
class ToolSpacing {
  static double xs(BuildContext context) => _forBreakpoint(context, 4, 4, 4, 4);
  static double sm(BuildContext context) => _forBreakpoint(context, 8, 8, 8, 8);
  static double md(BuildContext context) =>
      _forBreakpoint(context, 12, 12, 12, 16);
  static double lg(BuildContext context) =>
      _forBreakpoint(context, 16, 16, 20, 24);
  static double xl(BuildContext context) =>
      _forBreakpoint(context, 20, 24, 28, 32);
  static double xxl(BuildContext context) =>
      _forBreakpoint(context, 24, 32, 40, 48);
  static double xxxl(BuildContext context) =>
      _forBreakpoint(context, 32, 40, 48, 64);

  static double _forBreakpoint(
    BuildContext context,
    double compact,
    double medium,
    double expanded,
    double desktop,
  ) {
    final breakpoint = ToolBreakpoint.of(context);
    switch (breakpoint) {
      case ToolBreakpoint.compact:
        return compact;
      case ToolBreakpoint.medium:
        return medium;
      case ToolBreakpoint.expanded:
        return expanded;
      case ToolBreakpoint.desktop:
        return desktop;
    }
  }
}

/// Touch target sizes adapted to breakpoint.
class ToolTouchTarget {
  static double small(BuildContext context) =>
      _forBreakpoint(context, 40, 44, 48, 56);
  static double medium(BuildContext context) =>
      _forBreakpoint(context, 44, 48, 56, 64);
  static double large(BuildContext context) =>
      _forBreakpoint(context, 48, 56, 64, 72);

  static double _forBreakpoint(
    BuildContext context,
    double compact,
    double medium,
    double expanded,
    double desktop,
  ) {
    final breakpoint = ToolBreakpoint.of(context);
    switch (breakpoint) {
      case ToolBreakpoint.compact:
        return compact;
      case ToolBreakpoint.medium:
        return medium;
      case ToolBreakpoint.expanded:
        return expanded;
      case ToolBreakpoint.desktop:
        return desktop;
    }
  }
}

/// Base scaffold for all tool screens.
///
/// Provides consistent structure:
/// - AppBar with back button, title, 3-dot menu
/// - Main tool widget (takes available space)
/// - Optional bottom transport bar
/// - No bottom navigation bar (tools are full-screen)
///
/// Usage:
/// ```dart
/// ToolScreenScaffold(
///   title: 'Metronome',
///   menuItems: [...],
///   mainWidget: CentralTempoCircle(),
///   bottomWidget: BottomTransportBar(),
/// )
/// ```
class ToolScreenScaffold extends StatelessWidget {
  /// Screen title displayed in AppBar.
  final String title;

  /// Main tool widget (takes most of the screen).
  final Widget mainWidget;

  /// Optional widget below main widget (e.g., fine adjustment buttons).
  final Widget? secondaryWidget;

  /// Optional bottom widget (e.g., transport bar).
  final Widget? bottomWidget;

  /// Menu items for 3-dot menu.
  final List<PopupMenuEntry<dynamic>>? menuItems;

  /// Whether to show offline indicator.
  final bool showOfflineIndicator;

  const ToolScreenScaffold({
    super.key,
    required this.title,
    required this.mainWidget,
    this.secondaryWidget,
    this.bottomWidget,
    this.menuItems,
    this.showOfflineIndicator = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: MonoPulseColors.black,
        appBar: CustomAppBar.build(
          context,
          title: title,
          menuItems: menuItems,
          isTool: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (showOfflineIndicator) const OfflineIndicator.banner(),
              // Main tool widget (expandable)
              Expanded(flex: 1, child: mainWidget),
              // Secondary widget (optional, fixed height)
              if (secondaryWidget != null) ...[
                const SizedBox(height: 8),
                secondaryWidget!,
              ],
              // Bottom widget (optional, fixed height)
              if (bottomWidget != null) ...[
                const SizedBox(height: 8),
                bottomWidget!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Responsive layout for tool blocks.
///
/// Automatically rearranges blocks based on orientation:
/// - Portrait: Vertical stack
/// - Landscape: Side-by-side (when width allows)
///
/// Usage:
/// ```dart
/// ToolResponsiveLayout(
///   portraitBlocks: [block1, block2, block3],
///   landscapeBlocks: [
///     Row(children: [block1, block2]),
///     block3,
///   ],
/// )
/// ```
class ToolResponsiveLayout extends StatelessWidget {
  /// Blocks to show in portrait mode (vertical stack).
  final List<Widget> portraitBlocks;

  /// Blocks to show in landscape mode (can use Row).
  final List<Widget> landscapeBlocks;

  /// Minimum width for landscape layout (default 600px).
  final double landscapeBreakpoint;

  const ToolResponsiveLayout({
    super.key,
    required this.portraitBlocks,
    required this.landscapeBlocks,
    this.landscapeBreakpoint = 600,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final useLandscape = width >= landscapeBreakpoint;

        final blocks = useLandscape ? landscapeBlocks : portraitBlocks;

        if (useLandscape) {
          return Column(children: blocks);
        } else {
          return Column(children: portraitBlocks);
        }
      },
    );
  }
}

/// Modular tool block container.
///
/// Provides consistent styling for tool blocks:
/// - Optional card background
/// - Consistent padding
/// - Optional header
///
/// Usage:
/// ```dart
/// ToolBlock(
///   header: 'Time Signature',
///   child: TimeSignatureControls(),
/// )
/// ```
class ToolBlock extends StatelessWidget {
  /// Block content.
  final Widget child;

  /// Optional header text.
  final String? header;

  /// Whether to show card background.
  final bool showCard;

  /// Custom padding.
  final EdgeInsetsGeometry? padding;

  const ToolBlock({
    super.key,
    required this.child,
    this.header,
    this.showCard = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ?? EdgeInsets.all(ToolSpacing.lg(context));

    final child_widget = Padding(padding: effectivePadding, child: child);

    if (showCard) {
      return Card(
        color: MonoPulseColors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (header != null) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(
                  ToolSpacing.lg(context),
                  ToolSpacing.lg(context),
                  ToolSpacing.lg(context),
                  ToolSpacing.md(context),
                ),
                child: Text(
                  header!,
                  style: MonoPulseTypography.labelLarge.copyWith(
                    color: MonoPulseColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Divider(height: 1, color: MonoPulseColors.borderSubtle),
            ],
            child_widget,
          ],
        ),
      );
    }

    return child_widget;
  }
}
