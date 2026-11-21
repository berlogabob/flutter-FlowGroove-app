import '../../../models/audio_region.dart';
import 'song_map_letters.dart';
import 'song_map_view.dart';

/// Renames a group or moves a single occurrence into another group.
List<AudioRegion> editSectionName(
  SongMapView view, {
  required String occurrenceId,
  required String name,
  required bool move,
}) {
  final selected = view.sections.indexWhere((s) => s.id == occurrenceId);
  if (selected < 0 || name.isEmpty) return view.regions;

  final source = songMapGroupName(view.sections[selected].name);
  final sourceKey = source.toLowerCase();
  final targetKey = name.toLowerCase();
  if (move && sourceKey == targetKey) return view.regions;
  final groups = [
    for (final section in view.sections) songMapGroupName(section.name),
  ];
  final joinsGroup =
      sourceKey != targetKey &&
      groups.any((group) => group.toLowerCase() == targetKey);
  if (move && !joinsGroup) return view.regions;
  final counts = <String, int>{};
  List<AudioRegion>? updated;
  for (final (index, group) in groups.indexed) {
    final key = group.toLowerCase();
    final inSource = index == selected || (key.isNotEmpty && key == sourceKey);
    final inTarget = key == targetKey && joinsGroup;
    if (!inSource && !inTarget) continue;

    final oldName = view.sections[index].name;
    final staysInSource = move && inSource && index != selected;
    final base = staysInSource ? source : name;
    final suffix = joinsGroup
        ? ' ${counts.update(base.toLowerCase(), (n) => n + 1, ifAbsent: () => 1)}'
        : oldName.trim().substring(group.length);
    final newName = '$base$suffix';
    if (oldName == newName) continue;
    updated ??= [...view.regions];
    final (start, end) = view.sectionRange(index);
    for (var i = start; i <= end; i++) {
      final part = updated[i];
      final oldSection = part.section?.isNotEmpty == true
          ? part.section!
          : oldName;
      updated[i] = part.copyWith(
        section: part.sectionId != null || part.section?.isNotEmpty == true
            ? newName
            : null,
        name:
            part.name == oldSection ||
                (oldSection.isNotEmpty && part.name.startsWith(oldSection))
            ? '$newName${part.name.substring(oldSection.length)}'
            : part.name,
      );
    }
  }
  return updated ?? view.regions;
}

/// Moves the boundary after regions[index] to a caller-snapped time.
/// Both sides retain at least one bar. Within a section, the cut must
/// still allow all preceding parts to have 2, 4, or 8 bars.
List<AudioRegion> moveBoundary(
  List<AudioRegion> regions,
  int index,
  int newMs, {
  required AudioGrid grid,
}) {
  if (!_canEdit(grid) || !_isBoundary(regions, index)) return regions;
  final before = regions[index];
  final after = regions[index + 1];
  final left = _sectionAt(regions, index);
  if (_sameSection(before, after)) {
    final minMs = _barTime(grid, before.startMs, 1);
    final maxMs = _barTime(grid, after.endMs, -1);
    if (minMs > maxMs) return regions;
    final cut = newMs.clamp(minMs, maxMs);
    final start = left.first.startMs;
    final bars = ((cut - start) / grid.barMs).round();
    if (cut == before.endMs ||
        bars < 2 ||
        bars.isOdd ||
        cut != _barTime(grid, start, bars)) {
      return regions;
    }
    return [
      ...regions.take(left.start),
      ..._parts(
        left.first,
        start,
        left.last.endMs,
        grid,
        _partIds(regions),
        keepBoundaryMs: cut,
      ),
      ...regions.skip(left.end),
    ];
  }
  final right = _sectionAt(regions, index + 1);
  final minMs = _barTime(grid, left.first.startMs, 1);
  final maxMs = _barTime(grid, right.last.endMs, -1);
  if (minMs > maxMs) return regions;
  final cut = newMs.clamp(minMs, maxMs);
  if (cut == left.last.endMs) return regions;

  final ids = _partIds(regions);
  return [
    ...regions.take(left.start),
    ..._parts(left.first, left.first.startMs, cut, grid, ids),
    ..._parts(right.first, cut, right.last.endMs, grid, ids),
    ...regions.skip(right.end),
  ];
}

/// Deletes the boundary after regions[index], keeping the left section name.
List<AudioRegion> deleteBoundary(
  List<AudioRegion> regions,
  int index, {
  required AudioGrid grid,
  bool withinSection = false,
}) {
  if (!_canEdit(grid) || !_isBoundary(regions, index)) return regions;
  if (withinSection) {
    final left = regions[index];
    final right = regions[index + 1];
    if (!_sameSection(left, right)) return regions;
    return [
      ...regions.take(index),
      left.copyWith(endMs: right.endMs),
      ...regions.skip(index + 2),
    ];
  }
  final left = _sectionAt(regions, index);
  final right = _sectionAt(regions, index + 1);
  return [
    ...regions.take(left.start),
    ..._parts(
      left.first.copyWith(skip: left.first.skip && right.first.skip),
      left.first.startMs,
      right.last.endMs,
      grid,
      _partIds(regions),
      avoidBoundaryMs: regions[index].endMs,
    ),
    ...regions.skip(right.end),
  ];
}

/// Starts a new section or splits a part at the caller-snapped [ms].
/// A section split requires a bar on either side and may reuse a part seam.
List<AudioRegion> splitAt(
  List<AudioRegion> regions,
  int ms, {
  required AudioGrid grid,
  bool withinSection = false,
}) {
  if (!_canEdit(grid)) return regions;
  final i = regions.indexWhere((r) => r.startMs <= ms && ms < r.endMs);
  if (i < 0) return regions;
  if (withinSection) {
    final part = regions[i];
    if (ms == part.startMs) return regions;
    final legacy = part.sectionId == null && (part.section?.isEmpty ?? true);
    final sectionId = legacy ? part.id : part.sectionId;
    final section = legacy ? part.name : part.section;
    return [
      ...regions.take(i),
      part.copyWith(endMs: ms, sectionId: sectionId, section: section),
      AudioRegion(
        id: _partIds(regions)(part.id, ms),
        name: section ?? part.name,
        section: section,
        sectionId: sectionId,
        startMs: ms,
        endMs: part.endMs,
        skip: part.skip,
      ),
      ...regions.skip(i + 1),
    ];
  }
  final section = _sectionAt(regions, i);
  if (ms < _barTime(grid, section.first.startMs, 1) ||
      ms > _barTime(grid, section.last.endMs, -1)) {
    return regions;
  }

  final partName = RegExp(r'^PART ([A-Z]+)(?:\s|$)', caseSensitive: false);
  final used = {
    for (final r in regions)
      partName
          .firstMatch((r.section ?? r.name).trim())
          ?.group(1)
          ?.toUpperCase(),
  };
  var letter = 0;
  while (used.contains(_letter(letter, 65))) {
    letter++;
  }
  final name = 'Part ${_letter(letter, 65)} 1';
  final ids = _partIds(regions);
  final right = AudioRegion(
    id: ids(section.first.id, ms),
    name: name,
    section: name,
    startMs: ms,
    endMs: section.last.endMs,
    skip: section.first.skip,
  );
  return [
    ...regions.take(section.start),
    ..._parts(section.first, section.first.startMs, ms, grid, ids),
    ..._parts(right, ms, section.last.endMs, grid, ids),
    ...regions.skip(section.end),
  ];
}

bool _canEdit(AudioGrid grid) => grid.barMs.isFinite && grid.barMs >= 1;

bool _sameSection(AudioRegion left, AudioRegion right) {
  if (left.endMs != right.startMs || left.skip != right.skip) return false;
  if (left.sectionId != null || right.sectionId != null) {
    return left.sectionId != null && left.sectionId == right.sectionId;
  }
  final name = left.section;
  return name != null && name.isNotEmpty && name == right.section;
}

bool _isBoundary(List<AudioRegion> regions, int index) =>
    index >= 0 &&
    index + 1 < regions.length &&
    regions[index].endMs == regions[index + 1].startMs;

({int start, int end, AudioRegion first, AudioRegion last}) _sectionAt(
  List<AudioRegion> regions,
  int index,
) {
  var start = index;
  var end = index + 1;
  while (start > 0 && _sameSection(regions[start - 1], regions[start])) {
    start--;
  }
  while (end < regions.length && _sameSection(regions[end - 1], regions[end])) {
    end++;
  }
  return (
    start: start,
    end: end,
    first: regions[start],
    last: regions[end - 1],
  );
}

int _barTime(AudioGrid grid, int startMs, int bars) {
  final bar = grid.barAt(startMs);
  final nearest = bar.round();
  final start = grid.msOfBar(nearest) == startMs ? nearest : bar;
  return grid.msOfBar(start + bars);
}

String Function(String, int) _partIds(List<AudioRegion> regions) {
  final used = {for (final r in regions) r.id};
  return (firstPartId, startMs) {
    final base = '$firstPartId@$startMs';
    var id = base;
    for (var suffix = 2; !used.add(id); suffix++) {
      id = '$base-$suffix';
    }
    return id;
  };
}

String _letter(int index, int first) {
  final letter = String.fromCharCode(first + index % 26);
  return index < 26 ? letter : '${_letter(index ~/ 26 - 1, first)}$letter';
}

Iterable<AudioRegion> _parts(
  AudioRegion section,
  int startMs,
  int endMs,
  AudioGrid grid,
  String Function(String, int) newId, {
  int? keepBoundaryMs,
  int? avoidBoundaryMs,
}) sync* {
  final name = section.section?.isNotEmpty == true
      ? section.section!
      : section.name;
  var start = startMs;
  var bars = 0;
  var index = 0;
  while (start < endMs) {
    final limit = keepBoundaryMs != null && start < keepBoundaryMs
        ? keepBoundaryMs
        : endMs;
    final remaining = ((limit - start) / grid.barMs).round();
    // Match the detector's legal lengths. Only the last piece takes the
    // remainder, including any partial bar at an edited or file edge.
    var length = remaining >= 8 ? 8 : (remaining >= 4 ? 4 : 2);
    if (remaining > length &&
        _barTime(grid, startMs, bars + length) == avoidBoundaryMs) {
      length = switch (length) {
        8 => 4,
        4 => 2,
        _ => remaining,
      };
    }
    bars += length;
    final end = remaining <= length ? limit : _barTime(grid, startMs, bars);
    yield AudioRegion(
      id: index == 0 ? section.id : newId(section.id, start),
      name: name.isEmpty ? _letter(index, 97) : '$name ${_letter(index, 97)}',
      section: name,
      sectionId: section.sectionId,
      startMs: start,
      endMs: end,
      skip: section.skip,
    );
    start = end;
    index++;
  }
}
