import 'dart:typed_data';

import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/services/audio/song_structure.dart' hide AudioGrid;
import 'package:flutter_test/flutter_test.dart';

StructureUnit unit(double x, {double? low, List<double>? chroma}) =>
    (chroma: chroma ?? [1, x], timbre: [x, x], texture: [x, low ?? x]);
SongStructure decode(List<StructureUnit> units) => analyseStructureUnits(
  units,
  startsMs: [for (var i = 0; i < units.length; i++) i * 2000.0],
  endMs: units.length * 2000,
);

void main() {
  test('Jacobi known matrix, eigenvectors and random symmetric residual', () {
    final known = structureJacobi([
      [2, 1, 0],
      [1, 2, 0],
      [0, 0, 4],
    ]);
    for (var i = 0; i < 3; i++) {
      expect(known.values[i], closeTo([1, 3, 4][i], 1e-10));
    }
    var seed = 31;
    double noise() {
      seed = (1664525 * seed + 1013904223) % 4294967296;
      return seed / 4294967296 - 0.5;
    }

    final a = List.generate(20, (_) => List<double>.filled(20, 0));
    for (var i = 0; i < 20; i++) {
      for (var j = i; j < 20; j++) {
        a[i][j] = noise();
        a[j][i] = a[i][j];
      }
    }
    final before = [
      for (final row in a) [...row],
    ];
    for (final matrix in [
      [
        [2.0, 1.0, 0.0],
        [1.0, 2.0, 0.0],
        [0.0, 0.0, 4.0],
      ],
      a,
    ]) {
      final result = structureJacobi(matrix);
      for (var i = 0; i < matrix.length; i++) {
        for (var j = 0; j < matrix.length; j++) {
          var av = 0.0;
          var dot = 0.0;
          for (var r = 0; r < matrix.length; r++) {
            av += matrix[i][r] * result.vectors[r][j];
            dot += result.vectors[r][i] * result.vectors[r][j];
          }
          expect(av, closeTo(result.values[j] * result.vectors[i][j], 1e-8));
          expect(dot, closeTo(i == j ? 1 : 0, 1e-8));
        }
      }
    }
    expect(a, before);
  });
  test('reference A B A B C B recovers exact boundaries and recurrence', () {
    // The reference consumes 210 noise draws for its random-matrix check first.
    var seed = 31;
    double noise() {
      seed = (1664525 * seed + 1013904223) % 4294967296;
      return seed / 4294967296 - 0.5;
    }

    for (var i = 0; i < 210; i++) {
      noise();
    }
    const expected = [1, 2, 1, 2, 3, 2];
    final units = <StructureUnit>[];
    for (final kind in expected) {
      for (var bar = 0; bar < (kind == 3 ? 4 : 8); bar++) {
        final ch = <double>[];
        final tm = <double>[];
        for (var j = 1; j <= 12; j++) {
          ch.add(
            (j == kind * 3 ? 4 : 0) +
                (j == bar % 4 + 1 ? 0.3 : 0) +
                0.002 * noise(),
          );
          tm.add(kind * 2 + bar % 4 * 0.1 + j * kind * 0.1 + 0.002 * noise());
        }
        units.add((
          chroma: ch,
          timbre: tm,
          texture: [for (var j = 0; j < 6; j++) kind + 0.002 * noise()],
        ));
      }
    }
    final result = analyseStructureUnits(
      units,
      startsMs: [for (var i = 0; i < units.length; i++) i * 2000.0],
      endMs: units.length * 2000,
    );
    expect(result.sections.map((s) => s.startMs), [
      0,
      16000,
      32000,
      48000,
      64000,
      72000,
    ]);
    expect(result.sections.map((s) => s.label), ['A', 'B', 'A', 'B', 'C', 'B']);
    expect(result.sections.map((s) => s.name), [
      'Verse 1',
      'Chorus 1',
      'Verse 2',
      'Chorus 2',
      'Bridge 1',
      'Chorus 3',
    ]);
    for (var i = 0; i < result.parts.length; i++) {
      final p = result.parts[i];
      final s = result.sections[p.sectionIndex];
      expect(p.startMs, greaterThanOrEqualTo(s.startMs));
      expect(p.endMs, lessThanOrEqualTo(s.endMs));
      expect(p.endMs - p.startMs, greaterThanOrEqualTo(4000));
      expect(p.letter, matches(RegExp(r'^[a-z]$')));
      if (i > 0) expect(p.startMs, result.parts[i - 1].endMs);
    }
    expect(result.parts.first.startMs, 0);
    expect(result.parts.last.endMs, units.length * 2000);
    expect(result.levels.map((l) => l.k), [2, 3, 4, 5, 6, 7, 8, 9, 10]);
    // Lua reference levels: local novelty can rescue the final sections even
    // with a broken recurrence graph, so check the raw hierarchy as well.
    expect(result.levels.first.boundariesMs, [20000, 32000, 52000]);
    expect(result.levels.last.boundariesMs, [
      8000,
      16000,
      24000,
      32000,
      40000,
      48000,
      56000,
      64000,
      72000,
      80000,
    ]);
  });
  test(
    'drum entry anchors pre-intro, ignores silent tail and weak contrast',
    () {
      final body = [
        for (final kind in [1, 2, 1, 2, 3, 2])
          for (var i = 0; i < (kind == 3 ? 4 : 8); i++)
            unit(
              kind * 4,
              low: 20,
              chroma: [
                if (kind == 1) 4 else 0,
                if (kind == 2) 4 else 0,
                if (kind == 3) 4 else 0,
              ],
            ),
      ];
      final original = decode(body);
      for (final lead in [1, 2, 6, 9, 14]) {
        final prefixed = [
          for (var i = 0; i < lead; i++) unit(-10, low: 10, chroma: [0, 0, 0]),
          ...body,
        ];
        final anchored = decode(prefixed);
        expect(anchored.sections.first.endMs, lead * 2000);
        expect(anchored.sections.first.name, 'Intro 1');
        expect(
          anchored.sections.skip(1).map((s) => s.startMs),
          original.sections.map((s) => s.startMs + lead * 2000),
        );
        expect(
          decode([
            ...prefixed,
            unit(0, low: 0, chroma: [0, 0, 0]),
          ]).sections.first.endMs,
          lead * 2000,
        );
        for (final p in anchored.parts) {
          final section = anchored.sections[p.sectionIndex];
          expect(p.startMs, greaterThanOrEqualTo(section.startMs));
          expect(p.endMs, lessThanOrEqualTo(section.endMs));
          final size = (p.endMs - p.startMs) ~/ 2000;
          final length = (section.endMs - section.startMs) ~/ 2000;
          expect(
            [2, 4, 8].contains(size) ||
                (length.isOdd &&
                    p.endMs == section.endMs &&
                    size.isOdd &&
                    size <= 8),
            isTrue,
          );
        }
        final weak = decode([
          for (var i = 0; i < lead; i++) unit(-10, low: 17, chroma: [0, 0, 0]),
          ...body,
        ]);
        // The hierarchy includes the prefix only when the body was sliced.
        expect(weak.levels.first.boundariesMs.first, isNot(lead * 2000));
      }
    },
  );
  test('anchored eight-bar prior moves only to a stronger eight-bar cut', () {
    List<StructureUnit> phrase(int change) => [
      for (var i = 0; i < 40; i++)
        unit(i < change ? 1 : 6, chroma: i < 12 ? [1, 0] : [0, 1]),
    ];
    expect(
      structureRefineBoundaries(
        phrase(16),
        [0, 12, 40],
        anchored: true,
        noveltyThreshold: 100,
      ),
      [16, 40],
    );
    expect(
      structureRefineBoundaries(phrase(16), [0, 12, 40], noveltyThreshold: 100),
      [12, 40],
    );
    expect(
      structureRefineBoundaries(
        phrase(12),
        [0, 12, 40],
        anchored: true,
        noveltyThreshold: 100,
      ),
      [12, 40],
    );
  });
  test('strong novelty preserves a two-bar section', () {
    final sample = [
      for (var i = 0; i < 24; i++)
        unit(
          i < 10
              ? 0
              : i < 12
              ? 10
              : 2,
        ),
    ];
    expect(structureRefineBoundaries(sample, [0, 8, 24]), [10, 12, 24]);
  });
  test(
    'short terminal phrase merges through decay, longer tail stays separate',
    () {
      List<StructureUnit> ending(int tail) => [
        for (final (kind, length) in [(1, 16), (2, 4), (3, tail)])
          for (var i = 0; i < length; i++)
            unit(kind * 4, low: 20, chroma: [kind.toDouble(), 1]),
      ];
      expect(decode(ending(5)).sections.map((s) => s.endMs), [32000, 50000]);
      expect(decode(ending(8)).sections.length, 3);
    },
  );
  test(
    'adversarial labels and silence leave only 2/4/8 and final odd parts',
    () {
      for (var length = 1; length <= 33; length++) {
        final sample = [
          for (var i = 1; i <= length; i++)
            unit(
              i > length - 3 ? -20 : 0,
              low: 20,
              chroma: [(i % 3).toDouble(), 1],
            ),
        ];
        final plan = structurePracticeBoundaries(sample, [
          for (var i = 1; i <= length; i++) (i ~/ 3) % 3 + 1,
        ]);
        var first = 0;
        for (final last in plan) {
          final size = last - first;
          expect(
            [2, 4, 8].contains(size) ||
                (length.isOdd && last == length && size.isOdd && size <= 8),
            isTrue,
            reason: '$length bars: $plan',
          );
          first = last;
        }
        expect(first, length);
      }
    },
  );
  test('fixed grid alternative must obey phrase quantization too', () {
    final sample = [
      for (var i = 0; i < 24; i++) unit(0, low: 20, chroma: [1, 0]),
    ];
    final plan = structurePracticeBoundaries(
      sample,
      List.filled(24, 1),
      sectionEnds: [12, 24],
      phraseTarget: 6,
    );
    var first = 0;
    for (final last in plan) {
      expect([2, 4, 8], contains(last - first));
      first = last;
    }
    expect(first, 24);
  });
  test('PCM entry point rejects fewer than eight complete bars', () {
    expect(
      analyseStructure(Int16List(15 * 22050), 22050, const AudioGrid(bpm: 120)),
      isNull,
    );
    // A pickup is warmed up, not counted as a complete bar.
    expect(
      analyseStructure(
        Int16List(16 * 22050),
        22050,
        const AudioGrid(bpm: 120, offsetMs: 1000),
      ),
      isNull,
    );
    final result = analyseStructure(
      Int16List(18 * 22050),
      22050,
      const AudioGrid(bpm: 120, offsetMs: 1000),
    );
    expect(result, isNotNull);
    expect(result!.sections.first.startMs, 0);
    expect(result.sections.last.endMs, 18000);
  });
}
