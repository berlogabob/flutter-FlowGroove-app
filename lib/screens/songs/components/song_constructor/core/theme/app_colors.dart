import 'package:flutter/material.dart';

/// Color palette for Song Structure Constructor.
/// Adapted to work with MonoPulse dark theme.
class SectionColorPalette {
  SectionColorPalette._();

  /// Primary section colors (17 colors, vibrant for dark theme).
  static const List<Color> sectionColors = [
    Color(0xFF42A5F5), // Blue
    Color(0xFF66BB6A), // Green
    Color(0xFFEF5350), // Red
    Color(0xFFFFA726), // Orange
    Color(0xFFAB47BC), // Purple
    Color(0xFF26A69A), // Teal
    Color(0xFF5C6BC0), // Indigo
    Color(0xFFEC407A), // Pink
    Color(0xFF26C6DA), // Cyan
    Color(0xFF9CCC65), // Lime
    Color(0xFFFFCA28), // Amber
    Color(0xFF8D6E63), // Brown
    Color(0xFFBDBDBD), // Grey
    Color(0xFF78909C), // Blue Grey
    Color(0xFFD4E157), // Light Green
    Color(0xFF7E57C2), // Deep Purple
    Color(0xFFFF7043), // Deep Orange
  ];

  /// Material theme colors for color picker.
  static List<Color> get themeColors => [
    const Color(0xFFEF5350),
    const Color(0xFFEC407A),
    const Color(0xFFAB47BC),
    const Color(0xFF7E57C2),
    const Color(0xFF5C6BC0),
    const Color(0xFF42A5F5),
    const Color(0xFF4FC3F7),
    const Color(0xFF26C6DA),
    const Color(0xFF26A69A),
    const Color(0xFF66BB6A),
    const Color(0xFF9CCC65),
    const Color(0xFFD4E157),
    const Color(0xFFFFEE58),
    const Color(0xFFFFCA28),
    const Color(0xFFFFA726),
    const Color(0xFFFF7043),
    const Color(0xFF8D6E63),
    const Color(0xFFBDBDBD),
    const Color(0xFF78909C),
  ];

  /// Extended palette for color wheel (shades).
  static List<Color> get paletteColors => [
    const Color(0xFFEF5350),
    const Color(0xFFE57373),
    const Color(0xFFEF5350),
    const Color(0xFFE53935),
    const Color(0xFFEC407A),
    const Color(0xFFF06292),
    const Color(0xFFEC407A),
    const Color(0xFFD81B60),
    const Color(0xFFAB47BC),
    const Color(0xFFBA68C8),
    const Color(0xFFAB47BC),
    const Color(0xFF8E24AA),
    const Color(0xFF7E57C2),
    const Color(0xFF9575CD),
    const Color(0xFF7E57C2),
    const Color(0xFF5E35B1),
  ];

  /// Get color at index with fallback.
  static Color getColorAt(int index, {int shade = 300}) {
    if (index < 0 || index >= sectionColors.length) {
      return sectionColors.first;
    }
    return sectionColors[index];
  }

  /// Get contrasting text color for a background color.
  static Color getContrastingTextColor(Color bgColor) {
    final luminance = bgColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
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

  /// Get suggested colors for a section type.
  static List<Color> getSuggestedColors(String sectionName) {
    switch (sectionName.toLowerCase()) {
      case 'intro':
        return [
          const Color(0xFF64B5F6),
          const Color(0xFF4DD0E1),
          const Color(0xFF7986CB),
        ];
      case 'verse':
        return [
          const Color(0xFF81C784),
          const Color(0xFF4DB6AC),
          const Color(0xFFAED581),
        ];
      case 'chorus':
        return [
          const Color(0xFFE57373),
          const Color(0xFFFFB74D),
          const Color(0xFFF06292),
        ];
      case 'bridge':
        return [const Color(0xFFBA68C8), const Color(0xFF9575CD)];
      case 'outro':
        return [
          const Color(0xFF90A4AE),
          const Color(0xFFBDBDBD),
          const Color(0xFF4DD0E1),
        ];
      case 'instrumental':
        return [
          const Color(0xFFFFCA28),
          const Color(0xFFFFEE58),
          const Color(0xFFFFA726),
        ];
      case 'solo':
        return [
          const Color(0xFFBA68C8),
          const Color(0xFFF06292),
          const Color(0xFFE57373),
        ];
      case 'pause':
        return [
          const Color(0xFFBDBDBD),
          const Color(0xFF78909C),
          const Color(0xFF8D6E63),
        ];
      default:
        return [
          const Color(0xFFBDBDBD),
          const Color(0xFF64B5F6),
          const Color(0xFF81C784),
        ];
    }
  }

  /// Hex preset colors for quick selection.
  static const Map<String, int> hexPresets = {
    'EF5350': 0xFFEF5350, // Red
    '66BB6A': 0xFF66BB6A, // Green
    '42A5F5': 0xFF42A5F5, // Blue
    'FFA726': 0xFFFFA726, // Orange
    'AB47BC': 0xFFAB47BC, // Purple
    '26A69A': 0xFF26A69A, // Teal
  };
}

/// Common spacing and sizing constants adapted to MonoPulse.
class AppDimensions {
  AppDimensions._();

  /// Grid spacing for section picker.
  static const double gridSpacing = 8.0;

  /// Border radius for section cards.
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

/// Common duration presets.
class AppDurationPresets {
  AppDurationPresets._();

  static const List<int> presets = [1, 2, 3, 4];
  static const int minDuration = 1;
  static const int maxDuration = 4;
  static const int defaultDuration = 1;
}
