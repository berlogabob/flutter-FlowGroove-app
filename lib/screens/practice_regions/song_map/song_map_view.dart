import 'package:flutter/foundation.dart';

import '../../../models/audio_region.dart';
import 'song_map_letters.dart';

enum SongMapZoom { song, section, part }

String songMapRegionLetter(int index) => String.fromCharCode(65 + index % 26);

String songMapRegionName(AudioRegion region, int index) =>
    region.name.isEmpty ? 'Region ${songMapRegionLetter(index)}' : region.name;

/// Timeline and pad navigation over a snapshot of regions in file order.
class SongMapView extends ChangeNotifier {
  SongMapView({
    required this.regions,
    required this.durationMs,
    this.grid,
    this.includeSkipped = false,
  }) : assert(durationMs >= 0, 'Song duration must be nonnegative.') {
    letters = SongMapLetters(regions);
    final spans = <AudioRegion>[];
    for (var start = 0; start < regions.length;) {
      final first = regions[start];
      final key = songMapSectionKey(first);
      var end = start + 1;
      while (key != null &&
          end < regions.length &&
          songMapSectionKey(regions[end]) == key) {
        end++;
      }
      final parts = List<AudioRegion>.unmodifiable(
        regions
            .getRange(start, end)
            .where((region) => includeSkipped || !region.skip),
      );
      if (parts.isNotEmpty) {
        _parts.add(parts);
        _sectionRanges.add((start, end - 1));
        final sectionName = first.section;
        spans.add(
          parts.first.copyWith(
            name: sectionName == null || sectionName.isEmpty
                ? first.name
                : sectionName,
            startMs: first.startMs,
            endMs: regions[end - 1].endMs,
            skip: parts.every((region) => region.skip),
          ),
        );
      }
      start = end;
    }
    sections = List.unmodifiable(spans);
  }

  final List<AudioRegion> regions;
  final int durationMs;
  final AudioGrid? grid;
  final bool includeSkipped;
  late final SongMapLetters letters;
  late final List<AudioRegion> sections;
  final _parts = <List<AudioRegion>>[];
  final _sectionRanges = <(int, int)>[];

  int? _sectionIndex;
  int? _partIndex;

  int? get sectionIndex => _sectionIndex;
  int? get partIndex => _partIndex;

  SongMapZoom get level => switch ((_sectionIndex, _partIndex)) {
    (null, _) => SongMapZoom.song,
    (_, null) => SongMapZoom.section,
    _ => SongMapZoom.part,
  };

  ({int startMs, int endMs}) get viewport {
    final section = _sectionIndex;
    if (section == null) return (startMs: 0, endMs: durationMs);
    final part = _partIndex;
    final region = part == null ? sections[section] : _parts[section][part];
    final padding = _barMs.round();
    return (
      startMs: (region.startMs - padding).clamp(0, durationMs),
      endMs: (region.endMs + padding).clamp(0, durationMs),
    );
  }

  int get startMs => viewport.startMs;
  int get endMs => viewport.endMs;

  double get _barMs {
    final bar = grid?.barMs ?? 0;
    return bar.isFinite && bar > 0 ? bar : 0;
  }

  /// Uses viewport-relative coordinates, including positions past its edges.
  double msToX(int ms, double width) {
    final (:startMs, :endMs) = viewport;
    if (endMs <= startMs || width <= 0 || !width.isFinite) return 0;
    return (ms - startMs) / (endMs - startMs) * width;
  }

  int xToMs(double x, double width) {
    final (:startMs, :endMs) = viewport;
    if (endMs <= startMs || width <= 0 || !width.isFinite) return startMs;
    return startMs + (x / width * (endMs - startMs)).round();
  }

  int snapMs(int ms) {
    final audioGrid = grid;
    if (audioGrid == null || _barMs == 0) return ms;
    return switch (level) {
      SongMapZoom.song => ms,
      SongMapZoom.section => audioGrid.snap(ms, durationMs: durationMs),
      SongMapZoom.part => snapToBeat(audioGrid, ms, durationMs: durationMs),
    };
  }

  /// At song level these are section spans. At deeper levels they are parts.
  List<AudioRegion> children() {
    final section = _sectionIndex;
    return section == null ? sections : _parts[section];
  }

  SongMapLetter sectionLetter(int index) => letters[_sectionRanges[index].$1];

  (int, int) regionRange(int index) {
    if (_sectionIndex == null) return _sectionRanges[index];
    final region = regions.indexOf(_parts[_sectionIndex!][index]);
    return (region, region);
  }

  /// Keep the zoom anchored to the surviving region IDs after an edit.
  void restoreZoom(SongMapView previous) {
    final oldSection = previous.sectionIndex;
    if (oldSection == null) return;
    final partIds = previous._parts[oldSection].map((part) => part.id).toSet();
    final section = _parts.indexWhere(
      (parts) => parts.any((r) => partIds.contains(r.id)),
    );
    if (section < 0) return;
    _sectionIndex = section;
    final oldPart = previous.partIndex;
    if (oldPart == null) return;
    final partId = previous._parts[oldSection][oldPart].id;
    final part = _parts[section].indexWhere((region) => region.id == partId);
    if (part >= 0) _partIndex = part;
  }

  /// [index] indexes the pads returned by [children].
  void zoomIn(int index) {
    if (_partIndex != null || index < 0 || index >= children().length) return;
    if (_sectionIndex == null) {
      _sectionIndex = index;
    } else {
      _partIndex = index;
    }
    notifyListeners();
  }

  void zoomOut() {
    if (_sectionIndex == null) return;
    if (_partIndex == null) {
      _sectionIndex = null;
    } else {
      _partIndex = null;
    }
    notifyListeners();
  }

  void next() => _move(1);

  void previous() => _move(-1);

  void _move(int step) {
    final section = _sectionIndex;
    if (section == null) return;
    final part = _partIndex;
    if (part == null) {
      final target = section + step;
      if (target < 0 || target >= sections.length) return;
      _sectionIndex = target;
    } else {
      final target = part + step;
      if (target < 0 || target >= _parts[section].length) return;
      _partIndex = target;
    }
    notifyListeners();
  }
}
