import 'package:material_ui/material_ui.dart';

import '../../../models/audio_region.dart';
import '../../../theme/mono_pulse_theme.dart';

class SongMapLetter {
  const SongMapLetter(this.label, this.color);

  final String label;
  final Color color;

  Color get textColor => switch (color) {
    MonoPulseColors.section1 ||
    MonoPulseColors.section3 ||
    MonoPulseColors.section4 => MonoPulseColors.textHighEmphasis,
    _ => MonoPulseColors.charcoal,
  };
}

/// Group letters in file order, indexed by the original region positions.
class SongMapLetters {
  SongMapLetters(List<AudioRegion> regions) {
    var nextGroup = 0;
    SongMapLetter makeLetter() {
      final index = nextGroup++;
      return SongMapLetter(
        _letterAt(index, 65),
        _palette[index % _palette.length],
      );
    }

    (String?, String?)? previousSection;
    for (final region in regions) {
      final section = songMapSectionKey(region);
      if (section != null && section == previousSection) {
        _letters.add(_letters.last);
      } else {
        final name = region.section;
        final group = _group(name == null || name.isEmpty ? region.name : name);
        _letters.add(
          group.isEmpty ? makeLetter() : _groups.putIfAbsent(group, makeLetter),
        );
      }
      previousSection = section;
    }
  }

  static const _palette = [
    MonoPulseColors.section1,
    MonoPulseColors.section5,
    MonoPulseColors.section8,
    MonoPulseColors.section3,
    MonoPulseColors.section11,
    MonoPulseColors.section7,
    MonoPulseColors.section4,
    MonoPulseColors.section10,
  ];
  static final _occurrenceSuffix = RegExp(r'\s+\d+$');
  final _groups = <String, SongMapLetter>{};
  final _letters = <SongMapLetter>[];

  SongMapLetter operator [](int index) => _letters[index];

  SongMapLetter? forSectionName(String name) => _groups[_group(name)];

  static String _group(String name) =>
      name.trim().toLowerCase().replaceFirst(_occurrenceSuffix, '');
}

// The ID and name namespaces are distinct in linked and legacy maps.
(String?, String?)? songMapSectionKey(AudioRegion region) {
  final id = region.sectionId;
  final name = region.section;
  if (id != null) return (id, null);
  return name == null || name.isEmpty ? null : (null, name);
}

final _partLetters = RegExp(r'^[a-z]+$');

String songMapPartLetter(AudioRegion region, int index) {
  final section = region.section;
  if (section != null && region.name.startsWith('$section ')) {
    final label = region.name.substring(section.length + 1);
    if (_partLetters.hasMatch(label)) return label;
  }
  return _letterAt(index, 97);
}

String _letterAt(int index, int first) {
  final letter = String.fromCharCode(first + index % 26);
  return index < 26 ? letter : '${_letterAt(index ~/ 26 - 1, first)}$letter';
}
