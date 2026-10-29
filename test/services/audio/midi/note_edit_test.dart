import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/services/audio/midi/note_edit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('notesFromFlat / flatFromNotes', () {
    test('round-trips two notes', () {
      const flat = [0, 120, 60, 100, 240, 60, 64, 80];
      final notes = notesFromFlat(flat);

      expect(notes.length, 2);
      expect(notes.first.tick, 0);
      expect(notes.first.dur, 120);
      expect(notes.first.pitch, 60);
      expect(notes.first.vel, 100);
      expect(notes.last.tick, 240);
      expect(notes.last.dur, 60);
      expect(notes.last.pitch, 64);
      expect(notes.last.vel, 80);
      expect(flatFromNotes(notes), flat);
    });

    test('ignores a trailing partial quad', () {
      for (final tail in [
        [240],
        [240, 60],
        [240, 60, 64],
      ]) {
        final notes = notesFromFlat([0, 120, 60, 100, ...tail]);

        expect(notes.length, 1);
        expect(flatFromNotes(notes), [0, 120, 60, 100]);
      }
    });
  });

  group('cellActive', () {
    const notes = [MidiNote(tick: 0, dur: 120, pitch: 60, vel: 100)];

    test('is true for a note covering the cell', () {
      expect(
        cellActive(
          notes,
          cellStart: 30,
          cellTicks: 60,
          matches: (pitch) => pitch == 60,
        ),
        isTrue,
      );
    });

    test('is false for the adjacent cell', () {
      expect(
        cellActive(
          notes,
          cellStart: 120,
          cellTicks: 120,
          matches: (pitch) => pitch == 60,
        ),
        isFalse,
      );
    });
  });

  group('toggleCell', () {
    test('adds one note at the empty cell with its duration and pitch', () {
      final result = toggleCell(
        const [],
        cellStart: 240,
        cellTicks: 120,
        matches: (pitch) => pitch == 64,
        addPitch: 64,
      );

      expect(result.length, 1);
      expect(result.single.tick, 240);
      expect(result.single.dur, 120);
      expect(result.single.pitch, 64);
    });

    test('removes the overlapping note from an active cell', () {
      const overlapping = MidiNote(tick: 0, dur: 240, pitch: 60, vel: 100);
      const adjacent = MidiNote(tick: 240, dur: 120, pitch: 60, vel: 100);
      const otherPitch = MidiNote(tick: 120, dur: 120, pitch: 64, vel: 80);
      final result = toggleCell(
        const [overlapping, adjacent, otherPitch],
        cellStart: 120,
        cellTicks: 120,
        matches: (pitch) => pitch == 60,
        addPitch: 60,
      );

      expect(result, [otherPitch, adjacent]);
    });

    test('sorts the result by tick', () {
      final result = toggleCell(
        const [
          MidiNote(tick: 360, dur: 120, pitch: 60, vel: 100),
          MidiNote(tick: 0, dur: 120, pitch: 60, vel: 100),
        ],
        cellStart: 120,
        cellTicks: 120,
        matches: (pitch) => pitch == 60,
        addPitch: 60,
      );

      expect(result.map((note) => note.tick), [0, 120, 360]);
    });

    test('removes pitch 40 from a drum lane when addPitch is 38', () {
      final result = toggleCell(
        const [MidiNote(tick: 0, dur: 120, pitch: 40, vel: 100)],
        cellStart: 0,
        cellTicks: 120,
        matches: (pitch) => pitch == 38 || pitch == 40,
        addPitch: 38,
      );

      expect(result, isEmpty);
    });
  });
}
