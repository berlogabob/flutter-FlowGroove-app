import 'package:flutter/material.dart';
import '../../../../../../models/section.dart';
import 'app_colors.dart';

/// Manages color assignment for song sections.
///
/// This utility class centralizes all color-related logic for sections,
/// providing consistent color handling across the application.
class SectionColorManager {
  /// Cache of assigned colors for section names.
  final Map<String, Color> _colorCache = {};

  /// Get color for a section (custom or auto-assigned).
  Color getColorForSection(Section section) {
    // Return custom color if set
    if (section.colorValue != null) {
      return Color(section.colorValue!);
    }

    // Return cached color if available
    if (_colorCache.containsKey(section.name)) {
      return _colorCache[section.name]!;
    }

    // Generate and cache new color
    final color = _generateColorForName(section.name);
    _colorCache[section.name] = color;
    return color;
  }

  /// Generate a color based on section name hash.
  Color _generateColorForName(String name) {
    final index =
        name.hashCode.abs() % SectionColorPalette.sectionColors.length;
    return SectionColorPalette.getColorAt(index);
  }

  /// Get color for a section name (used in picker).
  Color getColorForName(String name) {
    if (_colorCache.containsKey(name)) {
      return _colorCache[name]!;
    }
    final color = _generateColorForName(name);
    _colorCache[name] = color;
    return color;
  }

  /// Clear color cache.
  void clearCache() {
    _colorCache.clear();
  }

  /// Remove a specific name from cache.
  void removeFromCache(String name) {
    _colorCache.remove(name);
  }

  /// Get suggested colors for a section type.
  List<Color> getSuggestedColors(String sectionName) {
    return SectionColorPalette.getSuggestedColors(sectionName);
  }

  /// Get all section colors from MonoPulse theme.
  List<Color> getThemeColors() {
    return SectionColorPalette.sectionColors;
  }

  /// Get section colors (same as theme colors - using MonoPulse system).
  List<Color> getPaletteColors() {
    return SectionColorPalette.sectionColors;
  }
}

/// Extension method to get color from Section directly.
extension SectionColorExtension on Section {
  /// Get the color for this section using the color manager.
  Color get color {
    if (colorValue != null) {
      return Color(colorValue!);
    }
    final index = colorIndex;
    return SectionColorPalette.getColorAt(index);
  }

  /// Get contrasting text color for this section's background.
  Color get contrastingTextColor {
    return SectionColorPalette.getContrastingTextColor(color);
  }
}
