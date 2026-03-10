import 'package:flutter/material.dart';
import '../../../../../../theme/mono_pulse_theme.dart';

/// Color palette for Song Structure Constructor.
/// Uses MonoPulse design system colors.
class SectionColorPalette {
  SectionColorPalette._();

  /// Primary section colors (14 colors from MonoPulse design system).
  static List<Color> get sectionColors => [
    MonoPulseColors.section1, // Pink
    MonoPulseColors.section2, // Purple
    MonoPulseColors.section3, // Deep Purple
    MonoPulseColors.section4, // Indigo
    MonoPulseColors.section5, // Light Blue
    MonoPulseColors.section6, // Cyan
    MonoPulseColors.section7, // Teal
    MonoPulseColors.section8, // Green
    MonoPulseColors.section9, // Light Green
    MonoPulseColors.section10, // Lime
    MonoPulseColors.section11, // Yellow
    MonoPulseColors.section12, // Amber
    MonoPulseColors.section13, // Orange
    MonoPulseColors.section14, // Deep Orange
  ];

  /// Get color at index with fallback.
  static Color getColorAt(int index) {
    if (index < 0 || index >= sectionColors.length) {
      return sectionColors.first;
    }
    return sectionColors[index];
  }

  /// Get contrasting text color for a background color.
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
  static const Map<String, int> hexPresets = {
    'EF5350': 0xFFEF5350, // Red (section1 similar)
    '66BB6A': 0xFF66BB6A, // Green (section8 similar)
    '42A5F5': 0xFF42A5F5, // Blue (section5 similar)
    'FFA726': 0xFFFFA726, // Orange (section13 similar)
    'AB47BC': 0xFFAB47BC, // Purple (section2 similar)
    '26A69A': 0xFF26A69A, // Teal (section7 similar)
  };
}

/// Common spacing and sizing constants using MonoPulse design system.
class AppDimensions {
  AppDimensions._();

  /// Grid spacing for section picker.
  static const double gridSpacing = 8.0;

  /// Border radius for section cards (using MonoPulseRadius.large).
  static const double cardBorderRadius = 12.0;

  /// Border radius for pills.
  static const double pillBorderRadius = 22.0;

  /// Section card leading width.
  static const double cardLeadingWidth = 12.0;

  /// Section card leading height.
  static const double cardLeadingHeight = 40.0;

  /// Minimum tap target size (Material Design).
  static const double minTapTarget = 48.0;

  /// Pill view height.
  static const double pillHeight = 45.0;

  /// Section picker dialog height (Parts/Colors tabs).
  static const double pickerTabHeight = 260.0;

  /// Color picker dialog height.
  static const double colorPickerHeight = 350.0;
}
