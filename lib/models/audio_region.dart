/// Practice regions on a song audio file: Reaper-style named time ranges
/// (Intro, Verse, Chorus…) that loop alone or as a contiguous run, so a
/// transition can be drilled. Stored on the recording's [SongLabEntry].
///
/// Times are milliseconds; bars are always derived from an optional
/// [AudioGrid], so a file with drifting tempo still works in seconds and
/// re-setting the grid never corrupts the regions.
library;

import 'dart:typed_data';

import 'section.dart';
import 'section_span.dart';

class AudioGrid {
  const AudioGrid({required this.bpm, this.offsetMs = 0, this.beatsPerBar = 4});

  factory AudioGrid.fromJson(Map<String, dynamic> json) => AudioGrid(
    bpm: (json['bpm'] as num?)?.toDouble() ?? 120,
    offsetMs: (json['offsetMs'] as num?)?.toInt() ?? 0,
    beatsPerBar: (json['beatsPerBar'] as num?)?.toInt() ?? 4,
  );

  final double bpm;

  /// Where bar 1 beat 1 lands in the file.
  final int offsetMs;
  final int beatsPerBar;

  double get barMs => 60000 / bpm * beatsPerBar;

  /// Zero-based bar position of [ms]; negative before the first downbeat.
  double barAt(int ms) => (ms - offsetMs) / barMs;

  int msOfBar(num bar) => (offsetMs + bar * barMs).round();

  /// Nearest bar line to [ms], kept inside the file.
  int snap(int ms, {required int durationMs}) =>
      msOfBar(barAt(ms).round()).clamp(0, durationMs);

  Map<String, dynamic> toJson() => {
    'bpm': bpm,
    'offsetMs': offsetMs,
    'beatsPerBar': beatsPerBar,
  };

  AudioGrid copyWith({double? bpm, int? offsetMs, int? beatsPerBar}) =>
      AudioGrid(
        bpm: bpm ?? this.bpm,
        offsetMs: offsetMs ?? this.offsetMs,
        beatsPerBar: beatsPerBar ?? this.beatsPerBar,
      );
}

class AudioRegion {
  const AudioRegion({
    required this.id,
    required this.name,
    required this.startMs,
    required this.endMs,
    this.sectionId,
  });

  factory AudioRegion.fromJson(Map<String, dynamic> json) => AudioRegion(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    startMs: (json['startMs'] as num?)?.toInt() ?? 0,
    endMs: (json['endMs'] as num?)?.toInt() ?? 0,
    sectionId: json['sectionId'] as String?,
  );

  final String id;
  final String name;
  final int startMs;
  final int endMs;

  /// Link into the song map ([Section.id]); each occurrence (Chorus 1,
  /// Chorus 2) is its own section, as in the song's structure list.
  final String? sectionId;

  int get lengthMs => endMs - startMs;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'startMs': startMs,
    'endMs': endMs,
    if (sectionId != null) 'sectionId': sectionId,
  };

  AudioRegion copyWith({
    String? name,
    int? startMs,
    int? endMs,
    String? sectionId,
  }) => AudioRegion(
    id: id,
    name: name ?? this.name,
    startMs: startMs ?? this.startMs,
    endMs: endMs ?? this.endMs,
    sectionId: sectionId ?? this.sectionId,
  );
}

/// Shortest region a split or drag may leave behind.
const int minRegionMs = 500;

/// Splits the file at [atMs]. With no regions yet the whole file becomes two
/// regions; otherwise the region under [atMs] is cut in two, the right half
/// unnamed. A cut too close to an edge, or outside every region, returns
/// [regions] unchanged.
List<AudioRegion> splitRegions(
  List<AudioRegion> regions, {
  required int atMs,
  required int durationMs,
  required String Function() newId,
}) {
  final source = regions.isEmpty
      ? [AudioRegion(id: newId(), name: '', startMs: 0, endMs: durationMs)]
      : regions;
  final i = source.indexWhere((r) => atMs > r.startMs && atMs < r.endMs);
  if (i < 0) return regions;
  final r = source[i];
  if (atMs - r.startMs < minRegionMs || r.endMs - atMs < minRegionMs) {
    return regions;
  }
  return [
    ...source.sublist(0, i),
    r.copyWith(endMs: atMs),
    AudioRegion(id: newId(), name: '', startMs: atMs, endMs: r.endMs),
    ...source.sublist(i + 1),
  ];
}

/// Moves the boundary between region [index] and the next one to [atMs],
/// keeping both at least [minRegionMs] long.
List<AudioRegion> moveBoundary(List<AudioRegion> regions, int index, int atMs) {
  if (index < 0 || index >= regions.length - 1) return regions;
  final left = regions[index];
  final right = regions[index + 1];
  final ms = atMs.clamp(left.startMs + minRegionMs, right.endMs - minRegionMs);
  return [
    ...regions.sublist(0, index),
    left.copyWith(endMs: ms),
    right.copyWith(startMs: ms),
    ...regions.sublist(index + 2),
  ];
}

/// Removes region [index], giving its time to the previous region (or the
/// next one when it is first), so the map stays gapless.
List<AudioRegion> mergeRegion(List<AudioRegion> regions, int index) {
  if (index < 0 || index >= regions.length) return regions;
  if (regions.length == 1) return const [];
  final r = regions[index];
  final out = [...regions]..removeAt(index);
  if (index > 0) {
    out[index - 1] = out[index - 1].copyWith(endMs: r.endMs);
  } else {
    out[0] = out[0].copyWith(startMs: r.startMs);
  }
  return out;
}

/// Loop selection as an inclusive index range. Tapping outside the current
/// run extends it to the tapped region (contiguous, like a Reaper time
/// selection across regions); tapping an end of a multi-region run drops that
/// end; tapping inside a run, or the only selected region, selects just it.
(int, int)? toggleSelection((int, int)? current, int tapped) {
  if (current == null) return (tapped, tapped);
  final (a, b) = current;
  if (tapped < a) return (tapped, b);
  if (tapped > b) return (a, tapped);
  if (a == b) return null;
  if (tapped == a) return (a + 1, b);
  if (tapped == b) return (a, b - 1);
  return (tapped, tapped);
}

/// Time span of the selection with [preRollMs] of lead-in before it.
(int, int) loopSpan(
  List<AudioRegion> regions,
  (int, int) selection, {
  int preRollMs = 0,
}) {
  final (a, b) = selection;
  final start = regions[a].startMs - preRollMs;
  return (start < 0 ? 0 : start, regions[b].endMs);
}

/// Links named regions to the song map ([Song.sections], one entry per
/// occurrence, in play order).
///
/// A song without sections gets one built from the named regions, in order,
/// with default durations — bars stay on the regions, because whether
/// `Section.duration` means phrases or bars is still undecided. A song that
/// already has a structure is never rewritten: the n-th "Chorus" region links
/// to the n-th "Chorus" section (names compared case-insensitively), and
/// regions with no counterpart are counted in `unmatched`.
({List<AudioRegion> regions, List<Section>? created, int unmatched})
linkToSongMap(
  List<AudioRegion> regions,
  List<Section> sections, {
  required String Function() newId,
}) {
  String key(String name) => name.trim().toLowerCase();
  final build = sections.isEmpty;
  final created = <Section>[];
  final seen = <String, int>{};
  var unmatched = 0;
  final linked = <AudioRegion>[];
  for (final r in regions) {
    if (r.name.trim().isEmpty) {
      linked.add(r);
    } else if (build) {
      final section = Section(id: newId(), name: r.name.trim());
      created.add(section);
      linked.add(r.copyWith(sectionId: section.id));
    } else {
      final k = key(r.name);
      final n = seen[k] = (seen[k] ?? 0) + 1;
      final matches = [
        for (final s in sections)
          if (key(s.name) == k) s,
      ];
      if (matches.length < n) {
        unmatched++;
        linked.add(r);
      } else {
        linked.add(r.copyWith(sectionId: matches[n - 1].id));
      }
    }
  }
  return (
    regions: linked,
    created: created.isEmpty ? null : created,
    unmatched: unmatched,
  );
}

/// Whether the song can play locked to the click: the engine runs on whole
/// BPM and the backing mixer has no time-stretch, so a fractional grid would
/// drift against the drums.
bool canSyncToClick(AudioGrid? grid) =>
    grid != null && (grid.bpm - grid.bpm.round()).abs() < 0.001;

/// Regions as bar spans on the click grid, bar 0 = the grid's first downbeat.
/// A region that rounds to no whole bar, or lies before the downbeat, gets no
/// span (it can't be launched in sync).
List<SectionSpan> regionSpans(List<AudioRegion> regions, AudioGrid grid) => [
  for (final r in regions)
    if (grid.barAt(r.startMs).round() >= 0 &&
        grid.barAt(r.endMs).round() > grid.barAt(r.startMs).round())
      SectionSpan(
        sectionId: r.id,
        startBar: grid.barAt(r.startMs).round(),
        bars: grid.barAt(r.endMs).round() - grid.barAt(r.startMs).round(),
      ),
];

/// Moves the song so its first downbeat sits on frame 0, as the backing
/// mixer expects: audio before it (a pickup) is dropped; a negative offset is
/// padded with silence.
Int16List alignToDownbeat(Int16List pcm, int offsetMs, int sampleRate) {
  final frames = (offsetMs * sampleRate / 1000).round();
  if (frames == 0) return pcm;
  if (frames > 0) {
    return frames >= pcm.length ? Int16List(0) : pcm.sublist(frames);
  }
  return Int16List(pcm.length - frames)
    ..setRange(-frames, pcm.length - frames, pcm);
}
