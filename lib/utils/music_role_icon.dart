/// Music role icon and display name utilities.
///
/// Maps internal role keys (e.g., 'sound_engineer') to user-friendly
/// display names ('Sound Engineer') and emoji icons (🔊).
///
/// Unknown roles fall back to title-case text with no icon.
library;

/// Built-in music role icons with emoji representations.
///
/// Keys are normalized (lowercase, underscores) for matching.
/// Unknown roles gracefully fall back to text-only display.
class MusicRoleIcon {
  MusicRoleIcon._();

  /// Canonical role keys mapped to emoji icons.
  static const Map<String, String> _icons = {
    'vocalist': '🎤',
    'lead_vocalist': '🎤',
    'backing_vocalist': '🎤',
    'guitarist': '🎸',
    'bassist': '🎵',
    'drummer': '🥁',
    'percussionist': '🪘',
    'keyboardist': '🎹',
    'pianist': '🎹',
    'sound_engineer': '🔊',
    'photographer': '📸',
    'videographer': '🎬',
    'saxophonist': '🎷',
    'violinist': '🎻',
    'cellist': '🎻',
    'trumpet': '🎺',
    'trombone': '🎺',
    'flute': '🪈',
    'harpist': '🎵',
    'dj': '🎚️',
    'manager': '💼',
    'producer': '🎛️',
    'composer': '🎼',
    'audio_engineer': '🔊',
    'lighting_engineer': '💡',
    'stage_manager': '📋',
    'roadie': '🔧',
    'backup_singer': '🎤',
    'rapper': '🎤',
    'mc': '🎤',
    'conductor': '🎼',
    'choir': '🎤',
  };

  /// Default popular roles shown in the picker suggestion grid.
  /// Ordered by estimated popularity.
  static const List<String> popularRoles = [
    'vocalist',
    'guitarist',
    'drummer',
    'keyboardist',
    'bassist',
    'sound_engineer',
    'photographer',
    'videographer',
    'saxophonist',
    'violinist',
    'dj',
    'manager',
    'producer',
    'percussionist',
    'composer',
  ];

  /// Get emoji icon for a role key, or null if not recognized.
  static String? getIcon(String role) {
    final key = _normalize(role);
    return _icons[key];
  }

  /// Get user-friendly display name for a role.
  ///
  /// Examples:
  /// - 'sound_engineer' → 'Sound Engineer'
  /// - 'DJ' → 'DJ'
  /// - 'guitarist' → 'Guitarist'
  static String getDisplayName(String role) {
    // Known roles have canonical display names
    final key = _normalize(role);
    switch (key) {
      case 'vocalist':
        return 'Vocalist';
      case 'lead_vocalist':
        return 'Lead Vocalist';
      case 'backing_vocalist':
        return 'Backing Vocalist';
      case 'backup_singer':
        return 'Backup Singer';
      case 'guitarist':
        return 'Guitarist';
      case 'bassist':
        return 'Bassist';
      case 'drummer':
        return 'Drummer';
      case 'percussionist':
        return 'Percussionist';
      case 'keyboardist':
        return 'Keyboardist';
      case 'pianist':
        return 'Pianist';
      case 'sound_engineer':
      case 'audio_engineer':
        return 'Sound Engineer';
      case 'photographer':
        return 'Photographer';
      case 'videographer':
        return 'Videographer';
      case 'saxophonist':
        return 'Saxophonist';
      case 'violinist':
        return 'Violinist';
      case 'cellist':
        return 'Cellist';
      case 'trumpet':
        return 'Trumpet';
      case 'trombone':
        return 'Trombone';
      case 'flute':
        return 'Flute';
      case 'harpist':
        return 'Harpist';
      case 'dj':
        return 'DJ';
      case 'manager':
        return 'Manager';
      case 'producer':
        return 'Producer';
      case 'composer':
        return 'Composer';
      case 'lighting_engineer':
        return 'Lighting Engineer';
      case 'stage_manager':
        return 'Stage Manager';
      case 'roadie':
        return 'Roadie';
      case 'rapper':
        return 'Rapper';
      case 'mc':
        return 'MC';
      case 'conductor':
        return 'Conductor';
      case 'choir':
        return 'Choir';
      default:
        // Fallback: title-case the input
        return _titleCase(role);
    }
  }

  /// Build display string with icon: "🎸 Guitarist"
  static String getDisplayWithIcon(String role) {
    final icon = getIcon(role);
    final name = getDisplayName(role);
    return icon != null ? '$icon $name' : name;
  }

  /// Normalize role key for comparison.
  static String _normalize(String role) {
    return role.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
  }

  /// Public, save-time key normaliser: trims, lowercases and snake_cases a
  /// role, then de-duplicates the list (so a typed "Sound Engineer" matches the
  /// predefined `sound_engineer`). Preserves first-seen order.
  static List<String> normalizeKeys(Iterable<String> roles) {
    final seen = <String>{};
    final result = <String>[];
    for (final role in roles) {
      final key = _normalize(role);
      if (key.isNotEmpty && seen.add(key)) result.add(key);
    }
    return result;
  }

  /// Convert snake_case to Title Case.
  static String _titleCase(String text) {
    return text
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  /// Check if a role is in the known icons list.
  static bool isKnown(String role) {
    return _icons.containsKey(_normalize(role));
  }
}
