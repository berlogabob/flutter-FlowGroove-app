import 'package:flutter/material.dart';
import '../../../../../../theme/mono_pulse_theme.dart';

/// Color palette for Song Structure Constructor.
/// Uses MonoPulse design system colors.
class SectionColorPalette {
  SectionColorPalette._();

  /// Primary section colors (14 colors from MonoPulse design system).
  /// Delegates to the canonical list rather than re-listing it.
  static List<Color> get sectionColors => MonoPulseColors.sectionColors;

  /// Get color at index with fallback.
  static Color getColorAt(int index) {
    if (index < 0 || index >= sectionColors.length) {
      return sectionColors.first;
    }
    return sectionColors[index];
  }

  /// Get contrasting text color for a background color.
  ///
  /// Intentional exception to the context.mp rule (#132): this contrasts
  /// against an arbitrary section swatch color, not the app's theme
  /// surface, so the result is correct regardless of light/dark mode. A
  /// static helper also has no BuildContext to read context.mp from.
  static Color getContrastingTextColor(Color bgColor) {
    return bgColor.computeLuminance() > 0.5
        ? MonoPulseColors.black
        : MonoPulseColors.textPrimary;
  }

  /// Convert color to hex string (RRGGBB format).
  static String colorToHex(Color color) {
    return '${(color.r * 255).round().toRadixString(16).padLeft(2, '0')}'
            '${(color.g * 255).round().toRadixString(16).padLeft(2, '0')}'
            '${(color.b * 255).round().toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  /// Parse hex string to Color.
  static Color? hexToColor(String hex) {
    if (hex.length != 6) return null;
    try {
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return null;
    }
  }

  /// Get suggested colors for a section type (using MonoPulse colors).
  static List<Color> getSuggestedColors(String sectionName) {
    switch (sectionName.toLowerCase()) {
      case 'intro':
        return [MonoPulseColors.section5, MonoPulseColors.section6, MonoPulseColors.section4];
      case 'verse':
        return [MonoPulseColors.section8, MonoPulseColors.section7, MonoPulseColors.section9];
      case 'chorus':
        return [MonoPulseColors.section1, MonoPulseColors.section13, MonoPulseColors.section2];
      case 'bridge':
        return [MonoPulseColors.section2, MonoPulseColors.section3];
      case 'outro':
        return [MonoPulseColors.section6, MonoPulseColors.textSecondary, MonoPulseColors.section5];
      case 'instrumental':
        return [MonoPulseColors.section12, MonoPulseColors.section11, MonoPulseColors.section13];
      case 'solo':
        return [MonoPulseColors.section2, MonoPulseColors.section2, MonoPulseColors.section1];
      case 'pause':
        return [MonoPulseColors.textSecondary, MonoPulseColors.textTertiary, MonoPulseColors.section10];
      default:
        return [MonoPulseColors.textSecondary, MonoPulseColors.section5, MonoPulseColors.section8];
    }
  }

  /// Hex preset colors for quick selection (using MonoPulse section colors).
  /// These are alternatives to the canonical 14-color section palette.
  static const Map<String, int> hexPresets = {
    'EF5350': 0xFFEF5350, // Red
    '66BB6A': 0xFF66BB6A, // Green
    '42A5F5': 0xFF42A5F5, // Blue
    'FFA726': 0xFFFFA726, // Orange
    'AB47BC': 0xFFAB47BC, // Purple
    '26A69A': 0xFF26A69A, // Teal
  };
}

/// Common spacing and sizing constants using MonoPulse design system.
/// Thin facade over MonoPulse tokens to allow gradual migration.
class AppDimensions {
  AppDimensions._();

  /// Grid spacing for section picker (re-exports MonoPulseSpacing.sm).
  static const double gridSpacing = MonoPulseSpacing.sm;

  /// Border radius for section cards (re-exports MonoPulseRadius.large).
  static const double cardBorderRadius = MonoPulseRadius.large;

  /// Border radius for pills.
  static const double pillBorderRadius = 22;

  /// Section card leading width.
  static const double cardLeadingWidth = 12;

  /// Section card leading height.
  static const double cardLeadingHeight = 40;

  /// Minimum tap target size (Material Design). Only a11y constant, not tokenized.
  static const double minTapTarget = 48;

  /// Pill view height.
  static const double pillHeight = 45;

  /// Section picker dialog height (Parts/Colors tabs).
  static const double pickerTabHeight = 260;

  /// Color picker dialog height.
  static const double colorPickerHeight = 350;
}
