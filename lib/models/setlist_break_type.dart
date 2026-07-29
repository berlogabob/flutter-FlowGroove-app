import 'package:flutter/material.dart';

import 'setlist.dart';

/// Break / section-divider types for a setlist. Standard types have a default
/// label + icon; `custom` uses a user-supplied label (e.g. a guest name like
/// "EUSTACE"). Stored on [SetlistItem.breakType]; the optional per-item
/// [SetlistItem.breakLabel] overrides the default label.
enum SetlistBreakType {
  breakPause('break_pause', 'Break', Icons.pause_circle_outline),
  setChange('set_change', 'Set change', Icons.playlist_play),
  guestSet('guest_set', 'Guest set', Icons.person_outline),
  encore('encore', 'Encore', Icons.star_outline),
  backup('backup', 'Backup songs', Icons.bookmark_outline),
  custom('custom', 'Section', Icons.horizontal_rule);

  const SetlistBreakType(this.id, this.defaultLabel, this.icon);

  final String id;
  final String defaultLabel;
  final IconData icon;

  /// Standard types offered in the picker; `custom` (declared last) carries a
  /// free-text label and is included in [all].
  static const List<SetlistBreakType> standard = [
    breakPause,
    setChange,
    guestSet,
    encore,
    backup,
  ];

  /// All types, in picker order (standard first, then custom).
  static List<SetlistBreakType> get all => values;

  static SetlistBreakType byId(String? id) =>
      values.firstWhere((t) => t.id == id, orElse: () => custom);

  /// The label to show for a break item: its custom label if set, else the
  /// type's default label.
  static String labelFor(String? typeId, String? customLabel) {
    if (customLabel != null && customLabel.trim().isNotEmpty) {
      return customLabel.trim();
    }
    return byId(typeId).defaultLabel;
  }
}
