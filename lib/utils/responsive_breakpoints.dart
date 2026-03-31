import 'package:flutter/material.dart';

/// Screen breakpoint categories for responsive design.
enum ScreenBreakpoint { mobile, tablet, desktop }

/// Determines the current screen breakpoint based on width.
ScreenBreakpoint getBreakpoint(double width) {
  if (width < 600) return ScreenBreakpoint.mobile;
  if (width <= 1024) return ScreenBreakpoint.tablet;
  return ScreenBreakpoint.desktop;
}

/// Extension to easily access breakpoint info from BuildContext.
extension ResponsiveContext on BuildContext {
  /// Get the current screen breakpoint.
  ScreenBreakpoint get breakpoint {
    final width = MediaQuery.of(this).size.width;
    return getBreakpoint(width);
  }

  /// Check if current breakpoint is mobile.
  bool get isMobile => breakpoint == ScreenBreakpoint.mobile;

  /// Check if current breakpoint is tablet.
  bool get isTablet => breakpoint == ScreenBreakpoint.tablet;

  /// Check if current breakpoint is desktop.
  bool get isDesktop => breakpoint == ScreenBreakpoint.desktop;

  /// Get responsive padding based on breakpoint.
  EdgeInsets get responsivePadding {
    switch (breakpoint) {
      case ScreenBreakpoint.mobile:
        return const EdgeInsets.all(16);
      case ScreenBreakpoint.tablet:
        return const EdgeInsets.all(24);
      case ScreenBreakpoint.desktop:
        return const EdgeInsets.all(32);
    }
  }

  /// Get responsive spacing between sections.
  double get sectionSpacing {
    switch (breakpoint) {
      case ScreenBreakpoint.mobile:
        return 24;
      case ScreenBreakpoint.tablet:
        return 32;
      case ScreenBreakpoint.desktop:
        return 48;
    }
  }
}

/// Responsive sizing values for widgets.
class ResponsiveSizes {
  /// Get avatar radius based on breakpoint.
  static double avatarRadius(ScreenBreakpoint breakpoint) {
    switch (breakpoint) {
      case ScreenBreakpoint.mobile:
        return 24;
      case ScreenBreakpoint.tablet:
        return 32;
      case ScreenBreakpoint.desktop:
        return 40;
    }
  }

  /// Get icon size based on breakpoint.
  static double iconSize(ScreenBreakpoint breakpoint) {
    switch (breakpoint) {
      case ScreenBreakpoint.mobile:
        return 18; // Smaller for 3-col mobile layout
      case ScreenBreakpoint.tablet:
        return 24;
      case ScreenBreakpoint.desktop:
        return 28;
    }
  }

  /// Get card aspect ratio based on breakpoint and card type.
  static double cardAspectRatio(ScreenBreakpoint breakpoint) {
    switch (breakpoint) {
      case ScreenBreakpoint.mobile:
        return 2.5; // More square for 3-col mobile layout
      case ScreenBreakpoint.tablet:
        return 3.5;
      case ScreenBreakpoint.desktop:
        return 4.0;
    }
  }

  /// Get statistics card aspect ratio (always more square for 3-col row).
  static double statCardAspectRatio(ScreenBreakpoint breakpoint) {
    switch (breakpoint) {
      case ScreenBreakpoint.mobile:
        return 1.5; // More vertical space for 3 stats in 1 row
      case ScreenBreakpoint.tablet:
        return 2.5;
      case ScreenBreakpoint.desktop:
        return 3.0;
    }
  }

  /// Get minimum card height based on breakpoint.
  static double minCardHeight(ScreenBreakpoint breakpoint) {
    switch (breakpoint) {
      case ScreenBreakpoint.mobile:
        return 80;
      case ScreenBreakpoint.tablet:
        return 90;
      case ScreenBreakpoint.desktop:
        return 100;
    }
  }

  /// Get value font size based on breakpoint.
  static double valueFontSize(ScreenBreakpoint breakpoint) {
    switch (breakpoint) {
      case ScreenBreakpoint.mobile:
        return 16; // Smaller for 3-col mobile layout
      case ScreenBreakpoint.tablet:
        return 20;
      case ScreenBreakpoint.desktop:
        return 24;
    }
  }

  /// Get label font size based on breakpoint.
  static double labelFontSize(ScreenBreakpoint breakpoint) {
    switch (breakpoint) {
      case ScreenBreakpoint.mobile:
        return 11;
      case ScreenBreakpoint.tablet:
        return 12;
      case ScreenBreakpoint.desktop:
        return 14;
    }
  }

  /// Get button font size based on breakpoint.
  static double buttonFontSize(ScreenBreakpoint breakpoint) {
    switch (breakpoint) {
      case ScreenBreakpoint.mobile:
        return 12;
      case ScreenBreakpoint.tablet:
        return 13;
      case ScreenBreakpoint.desktop:
        return 14;
    }
  }

  /// Get grid cross axis count based on breakpoint and section.
  static int gridCrossAxisCount(
    ScreenBreakpoint breakpoint, {
    required int maxColumns,
  }) {
    switch (breakpoint) {
      case ScreenBreakpoint.mobile:
        return 1;
      case ScreenBreakpoint.tablet:
        return 2;
      case ScreenBreakpoint.desktop:
        return maxColumns;
    }
  }
}
