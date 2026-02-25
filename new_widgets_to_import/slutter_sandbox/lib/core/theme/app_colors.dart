import 'package:flutter/material.dart';

/// Centralized color palettes for the Song Structure Constructor.
/// 
/// This class provides consistent color schemes across all widgets
/// and eliminates duplicate color definitions.
class AppColorPalette {
  AppColorPalette._();

  /// Primary section colors palette (17 colors)
  static const List<Color> sectionColors = [
    Colors.blue,
    Colors.green,
    Colors.red,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
    Colors.cyan,
    Colors.lime,
    Colors.amber,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
    Colors.lightGreen,
    Colors.deepPurple,
    Colors.deepOrange,
  ];

  /// Material theme colors for color picker
  static List<Color> get themeColors => [
        Colors.red[300]!,
        Colors.pink[300]!,
        Colors.purple[300]!,
        Colors.deepPurple[300]!,
        Colors.indigo[300]!,
        Colors.blue[300]!,
        Colors.lightBlue[300]!,
        Colors.cyan[300]!,
        Colors.teal[300]!,
        Colors.green[300]!,
        Colors.lightGreen[300]!,
        Colors.lime[300]!,
        Colors.yellow[600]!,
        Colors.amber[400]!,
        Colors.orange[300]!,
        Colors.deepOrange[300]!,
        Colors.brown[300]!,
        Colors.grey[400]!,
        Colors.blueGrey[300]!,
      ];

  /// Extended palette for color wheel (shades)
  static List<Color> get paletteColors => [
        Colors.red[300]!,
        Colors.red[400]!,
        Colors.red[500]!,
        Colors.red[600]!,
        Colors.pink[300]!,
        Colors.pink[400]!,
        Colors.pink[500]!,
        Colors.pink[600]!,
        Colors.purple[300]!,
        Colors.purple[400]!,
        Colors.purple[500]!,
        Colors.purple[600]!,
        Colors.deepPurple[300]!,
        Colors.deepPurple[400]!,
        Colors.deepPurple[500]!,
        Colors.deepPurple[600]!,
      ];

  /// Get color at index with fallback
  static Color getColorAt(int index, {int shade = 300}) {
    if (index < 0 || index >= sectionColors.length) {
      return Colors.blue;
    }
    final baseColor = sectionColors[index];
    return _getColorWithShade(baseColor, shade);
  }

  /// Get a color with specific shade from a base MaterialColor
  static Color _getColorWithShade(Color color, int shade) {
    if (color is MaterialColor) {
      return color[shade] ?? color;
    }
    return color;
  }

  /// Get contrasting text color for a background color
  static Color getContrastingTextColor(Color bgColor) {
    final luminance = bgColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  /// Convert color to hex string (RRGGBB format)
  static String colorToHex(Color color) {
    return '${(color.r * 255).round().toRadixString(16).padLeft(2, '0')}'
        '${(color.g * 255).round().toRadixString(16).padLeft(2, '0')}'
        '${(color.b * 255).round().toRadixString(16).padLeft(2, '0')}'.toUpperCase();
  }

  /// Parse hex string to Color
  static Color? hexToColor(String hex) {
    if (hex.length != 6) return null;
    try {
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return null;
    }
  }

  /// Get suggested colors for a section type
  static List<Color> getSuggestedColors(String sectionName) {
    switch (sectionName.toLowerCase()) {
      case 'intro':
        return [Colors.blue[300]!, Colors.cyan[300]!, Colors.indigo[300]!];
      case 'verse':
        return [Colors.green[300]!, Colors.teal[300]!, Colors.lightGreen[300]!];
      case 'chorus':
        return [Colors.red[300]!, Colors.orange[300]!, Colors.pink[300]!];
      case 'bridge':
        return [Colors.purple[300]!, Colors.deepPurple[300]!];
      case 'outro':
        return [Colors.blueGrey[300]!, Colors.grey[400]!, Colors.cyan[300]!];
      case 'instrumental':
        return [Colors.amber[400]!, Colors.yellow[600]!, Colors.orange[300]!];
      case 'solo':
        return [Colors.purple[300]!, Colors.pink[300]!, Colors.red[300]!];
      case 'pause':
        return [Colors.grey[400]!, Colors.blueGrey[300]!, Colors.brown[300]!];
      default:
        return [Colors.grey[300]!, Colors.blue[300]!, Colors.green[300]!];
    }
  }

  /// Hex preset colors for quick selection
  static const Map<String, int> hexPresets = {
    'EF5350': 0xFFFF5350, // Red
    '66BB6A': 0xFF66BB6A, // Green
    '42A5F5': 0xFF42A5F5, // Blue
    'FFA726': 0xFFFFA726, // Orange
    'AB47BC': 0xFFAB47BC, // Purple
    '26A69A': 0xFF26A69A, // Teal
  };
}

/// Common spacing and sizing constants
class AppDimensions {
  AppDimensions._();

  /// Grid spacing for section picker
  static const double gridSpacing = 8.0;

  /// Border radius for section cards
  static const double cardBorderRadius = 12.0;

  /// Border radius for pills
  static const double pillBorderRadius = 22.0;

  /// Section card leading width
  static const double cardLeadingWidth = 12.0;

  /// Section card leading height
  static const double cardLeadingHeight = 40.0;

  /// Minimum tap target size (Material Design)
  static const double minTapTarget = 48.0;

  /// Pill view height
  static const double pillHeight = 45.0;

  /// Section picker dialog height (Parts/Colors tabs)
  static const double pickerTabHeight = 260.0;

  /// Color picker dialog height
  static const double colorPickerHeight = 350.0;
}

/// Common duration presets
class AppDurationPresets {
  AppDurationPresets._();

  static const List<int> presets = [1, 2, 3, 4];
  static const int minDuration = 1;
  static const int maxDuration = 4;
  static const int defaultDuration = 1;
}

/// Common text styles
class AppTextStyles {
  AppTextStyles._();

  static TextStyle sectionTitle(BuildContext context) {
    return Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ) ??
        const TextStyle(fontWeight: FontWeight.bold);
  }

  static TextStyle sectionSubtitle(BuildContext context) {
    return Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ) ??
        TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
  }

  static TextStyle sectionNotes(BuildContext context) {
    return Theme.of(context).textTheme.bodySmall?.copyWith(
          fontStyle: FontStyle.italic,
        ) ??
        const TextStyle(fontStyle: FontStyle.italic);
  }
}
