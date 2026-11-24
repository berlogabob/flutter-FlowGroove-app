import '../../../models/audio_region.dart';
import 'song_map_letters.dart';
import 'song_map_view.dart';

final _autoName = RegExp(r'^Part [A-Z]+ \d+$');

/// Makes every auto-named section (`Part <LETTERS> <n>`) agree with its
/// badge: the letter of its group and its occurrence number in that group.
/// Other names (typed or semantic) are never touched, a group that mixes
/// auto and other names is left alone, and a rename that would merge two
/// groups is skipped, so grouping and badges never change. Returns the
/// same list when nothing needs to change; running it twice is a no-op.
List<AudioRegion> normalizeAutoSectionNames(List<AudioRegion> regions) {
  if (regions.isEmpty) return regions;
  final view = SongMapView(
    regions: regions,
    durationMs: 0,
    includeSkipped: true,
  );
  try {
    final keys = [
      for (final s in view.sections) songMapGroupName(s.name).toLowerCase(),
    ];
    final members = <String, List<int>>{};
    for (final (i, key) in keys.indexed) {
      if (key.isNotEmpty) members.putIfAbsent(key, () => []).add(i);
    }
    // Final group key per auto group, or its own key when it stays as is.
    final target = <String, String>{};
    final skipped = <String>{};
    for (final entry in members.entries) {
      final auto = entry.value.every(
        (i) => _autoName.hasMatch(view.sections[i].name),
      );
      if (!auto) skipped.add(entry.key);
      target[entry.key] = auto
          ? 'part ${view.sectionLetter(entry.value.first).label.toLowerCase()}'
          : entry.key;
    }
    // Skip renames that would land two groups on the same key.
    for (var changed = true; changed;) {
      changed = false;
      final owner = <String, int>{};
      for (final t in target.values) {
        owner[t] = (owner[t] ?? 0) + 1;
      }
      for (final key in target.keys.toList()) {
        if (!skipped.contains(key) && owner[target[key]]! > 1) {
          skipped.add(key);
          target[key] = key;
          changed = true;
        }
      }
    }

    List<AudioRegion>? updated;
    for (final entry in members.entries) {
      if (skipped.contains(entry.key)) continue;
      final label = view.sectionLetter(entry.value.first).label;
      for (final (n, index) in entry.value.indexed) {
        final oldName = view.sections[index].name;
        final newName = 'Part $label ${n + 1}';
        if (oldName == newName) continue;
        updated ??= [...regions];
        final (start, end) = view.sectionRange(index);
        for (var i = start; i <= end; i++) {
          final part = updated[i];
          final hasSection =
              part.sectionId != null || part.section?.isNotEmpty == true;
          final oldSection = part.section?.isNotEmpty == true
              ? part.section!
              : oldName;
          final rest = part.name.startsWith(oldSection)
              ? part.name.substring(oldSection.length)
              : null;
          updated[i] = part.copyWith(
            section: hasSection ? newName : null,
            name: rest != null && (rest.isEmpty || rest.startsWith(' '))
                ? '$newName$rest'
                : part.name,
          );
        }
      }
    }
    return updated ?? regions;
  } finally {
    view.dispose();
  }
}
