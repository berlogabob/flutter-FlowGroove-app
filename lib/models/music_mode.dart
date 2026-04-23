import 'package:flutter/material.dart';

/// Music mode model for tuner scale visualization
/// Represents different musical modes/scales with their interval patterns
class MusicMode {
  final String name;
  final String shortName;
  final List<int> intervals; // Semitone intervals from root
  final IconData icon;
  final String description;

  const MusicMode({
    required this.name,
    required this.shortName,
    required this.intervals,
    required this.icon,
    this.description = '',
  });

  /// Check if a note index (0-11, C-B) is in this scale
  bool containsNote(int noteIndex) {
    return intervals.contains(noteIndex % 12);
  }

  @override
  String toString() => name;
}

/// All available music modes for cycling
const List<MusicMode> allMusicModes = [
  MusicMode(
    name: 'Chromatic',
    shortName: 'CHR',
    intervals: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    icon: Icons.grid_on,
    description: 'All 12 notes',
  ),
  MusicMode(
    name: 'Ionian (Major)',
    shortName: 'ION',
    intervals: [0, 2, 4, 5, 7, 9, 11],
    icon: Icons.wb_sunny_outlined,
    description: 'Happy, bright sound',
  ),
  MusicMode(
    name: 'Dorian',
    shortName: 'DOR',
    intervals: [0, 2, 3, 5, 7, 9, 10],
    icon: Icons.waves_outlined,
    description: 'Jazzy, soulful minor',
  ),
  MusicMode(
    name: 'Phrygian',
    shortName: 'PHR',
    intervals: [0, 1, 3, 5, 7, 8, 10],
    icon: Icons.emoji_events_outlined,
    description: 'Spanish, exotic flavor',
  ),
  MusicMode(
    name: 'Lydian',
    shortName: 'LYD',
    intervals: [0, 2, 4, 6, 7, 9, 11],
    icon: Icons.star_border_outlined,
    description: 'Dreamy, ethereal',
  ),
  MusicMode(
    name: 'Mixolydian',
    shortName: 'MIX',
    intervals: [0, 2, 4, 5, 7, 9, 10],
    icon: Icons.compass_calibration_outlined,
    description: 'Bluesy, rock dominant',
  ),
  MusicMode(
    name: 'Aeolian (Minor)',
    shortName: 'AEO',
    intervals: [0, 2, 3, 5, 7, 8, 10],
    icon: Icons.nights_stay_outlined,
    description: 'Natural minor, sad',
  ),
  MusicMode(
    name: 'Locrian',
    shortName: 'LOC',
    intervals: [0, 1, 3, 5, 6, 8, 10],
    icon: Icons.warning_amber_outlined,
    description: 'Dark, unstable',
  ),
  MusicMode(
    name: 'Major Pentatonic',
    shortName: 'PNT',
    intervals: [0, 2, 4, 7, 9],
    icon: Icons.music_note_outlined,
    description: 'Simple, versatile',
  ),
  MusicMode(
    name: 'Minor Pentatonic',
    shortName: 'mPNT',
    intervals: [0, 3, 5, 7, 10],
    icon: Icons.music_off_outlined,
    description: 'Rock/blues staple',
  ),
  MusicMode(
    name: 'Blues',
    shortName: 'BLU',
    intervals: [0, 3, 5, 6, 7, 10],
    icon: Icons.water_drop_outlined,
    description: 'Classic blues scale',
  ),
];

/// Default mode index (Chromatic)
const int defaultModeIndex = 0;
