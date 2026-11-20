import 'package:flutter/foundation.dart';

import '../../../models/audio_region.dart';

enum SongMapZoom { song, section, part }

/// Timeline and pad navigation over a snapshot of regions in file order.
class SongMapView extends ChangeNotifier {
  SongMapView({
    required List<AudioRegion> regions,
    required this.durationMs,
    this.grid,
  }) : assert(durationMs >= 0, 'Song duration must be nonnegative.') {
    final sections = <AudioRegion>[];
    for (var start = 0; start < regions.length;) {
      final first = regions[start];
      final key = _sectionKey(first);
      var end = start + 1;
      while (key != null &&
          end < regions.length &&
          _sectionKey(regions[end]) == key) {
        end++;
      }
      final parts = List<AudioRegion>.unmodifiable(
        regions.getRange(start, end).where((region) => !region.skip),
      );
      if (parts.isNotEmpty) {
        _parts.add(parts);
        final sectionName = first.section;
        sections.add(
          parts.first.copyWith(
            name: sectionName == null || sectionName.isEmpty
                ? first.name
                : sectionName,
            startMs: first.startMs,
            endMs: regions[end - 1].endMs,
          ),
        );
      }
      start = end;
    }
    _sections = List.unmodifiable(sections);
  }

  final int durationMs;
  final AudioGrid? grid;
  late final List<AudioRegion> _sections;
  final _parts = <List<AudioRegion>>[];

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
    final region = part == null ? _sections[section] : _parts[section][part];
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

  // Keep the ID and name namespaces distinct when reading linked and legacy maps.
  static (String?, String?)? _sectionKey(AudioRegion region) {
    final id = region.sectionId;
    final name = region.section;
    if (id != null) return (id, null);
    return name == null || name.isEmpty ? null : (null, name);
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
    return section == null ? _sections : _parts[section];
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
      if (target < 0 || target >= _sections.length) return;
      _sectionIndex = target;
    } else {
      final target = part + step;
      if (target < 0 || target >= _parts[section].length) return;
      _partIndex = target;
    }
    notifyListeners();
  }
}
