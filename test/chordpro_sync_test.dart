import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/models/section.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/screens/songs/chordpro_sync_controller.dart';
import 'package:flowgroove/utils/chordpro.dart';

void main() {
  Song blank() => Song(
    id: 'x',
    title: '',
    artist: '',
    createdAt: DateTime(2020),
    updatedAt: DateTime(2020),
  );

  group('x_flowgroove_section extras round-trip', () {
    test('bars + colour survive songToChordPro -> chordProToSong', () {
      final song = blank().copyWith(
        title: 'T',
        sections: [
          Section(
            id: 's1',
            name: 'Verse 1',
            duration: 4,
            colorValue: 0xFFE65100,
            chordChart: '[Am]hi',
          ),
        ],
      );
      final parsed = chordProToSong(songToChordPro(song), base: blank());
      expect(parsed.sections.single.duration, 4);
      expect(parsed.sections.single.colorValue, 0xFFE65100);
      expect(parsed.unknownDirectives, isEmpty); // x_flowgroove_section is known
    });
  });

  group('reconcileSections', () {
    test('chords-only text edit keeps id/duration/colour', () {
      final existing = [
        Section(
          id: 'v1',
          name: 'Verse',
          duration: 3,
          colorValue: 0xFF112233,
          chordChart: '[Am]old',
        ),
      ];
      // Parsed from hand-typed text (no extras directive) → duration 1, no colour.
      final parsed = [Section(id: 'cp_sec_0', name: 'Verse', chordChart: '[Am]new')];
      final out = reconcileSections(existing, parsed);
      expect(out.single.id, 'v1'); // identity preserved
      expect(out.single.duration, 3); // extra preserved
      expect(out.single.colorValue, 0xFF112233); // extra preserved
      expect(out.single.chordChart, '[Am]new'); // content updated
    });

    test('reorder preserves each section identity', () {
      final existing = [
        Section(id: 'a', name: 'Verse', colorValue: 0xFFAAAAAA),
        Section(id: 'b', name: 'Chorus', colorValue: 0xFFBBBBBB),
      ];
      final parsed = [
        Section(id: 'x', name: 'Chorus'),
        Section(id: 'y', name: 'Verse'),
      ];
      final out = reconcileSections(existing, parsed);
      expect(out.map((s) => s.name).toList(), ['Chorus', 'Verse']);
      expect(out[0].id, 'b'); // Chorus kept its id/colour
      expect(out[0].colorValue, 0xFFBBBBBB);
      expect(out[1].id, 'a');
    });

    test('repeated names match in order', () {
      final existing = [
        Section(id: 'c1', name: 'Chorus', colorValue: 0xFF111111),
        Section(id: 'c2', name: 'Chorus', colorValue: 0xFF222222),
      ];
      final parsed = [
        Section(id: 'p1', name: 'Chorus'),
        Section(id: 'p2', name: 'Chorus'),
      ];
      final out = reconcileSections(existing, parsed);
      expect(out[0].id, 'c1');
      expect(out[0].colorValue, 0xFF111111);
      expect(out[1].id, 'c2');
      expect(out[1].colorValue, 0xFF222222);
    });

    test('unmatched parsed section is added as new', () {
      final existing = [Section(id: 'v1', name: 'Verse')];
      final parsed = [
        Section(id: 'p1', name: 'Verse'),
        Section(id: 'p2', name: 'Bridge'),
      ];
      final out = reconcileSections(existing, parsed);
      expect(out.length, 2);
      expect(out[0].id, 'v1');
      expect(out[1].id, 'p2'); // new section kept as-is
      expect(out[1].name, 'Bridge');
    });
  });

  group('ChordProSyncController', () {
    test('updateFromMap regenerates the text', () {
      final c = ChordProSyncController(sections: []);
      c.updateFromMap([Section(id: 'a', name: 'Intro', chordChart: '[C]')]);
      expect(c.sections.single.name, 'Intro');
      expect(c.text, contains('Intro'));
      c.dispose();
    });

    test('debounced text edit reconciles onto existing structure', () async {
      final c = ChordProSyncController(
        sections: [
          Section(
            id: 'v1',
            name: 'Verse',
            duration: 3,
            colorValue: 0xFF112233,
            chordChart: '[Am]old',
          ),
        ],
        debounce: const Duration(milliseconds: 10),
      );
      c.updateFromText(c.text.replaceAll('[Am]old', '[Am]new'));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(c.sections.single.id, 'v1'); // identity kept
      expect(c.sections.single.duration, 3); // extra kept
      expect(c.sections.single.colorValue, 0xFF112233);
      expect(c.sections.single.chordChart, contains('[Am]new'));
      c.dispose();
    });

    test('isImportConflict only when structure differs over a non-empty map', () {
      const doc = '{start_of_chorus: Chorus}\n[C]x\n{end_of_chorus}';
      final withMap = ChordProSyncController(
        sections: [Section(id: 'a', name: 'Verse')],
      );
      expect(withMap.isImportConflict(doc), isTrue);
      final empty = ChordProSyncController(sections: []);
      expect(empty.isImportConflict(doc), isFalse);
      withMap.dispose();
      empty.dispose();
    });

    test('applyImport replace vs append', () {
      final c = ChordProSyncController(
        sections: [Section(id: 'a', name: 'Verse')],
      );
      c.applyImport([Section(id: 'b', name: 'Chorus')], ImportMode.append);
      expect(c.sections.map((s) => s.name).toList(), ['Verse', 'Chorus']);
      c.applyImport([Section(id: 'z', name: 'Outro')], ImportMode.replace);
      expect(c.sections.map((s) => s.name).toList(), ['Outro']);
      c.dispose();
    });
  });
}
