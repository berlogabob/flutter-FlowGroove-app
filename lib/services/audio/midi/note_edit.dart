/// Pure helpers for turning a flat note vector into [MidiNote]s and back, and
/// for toggling notes inside a single tick range.
///
/// Deliberately side-effect free: every function returns a fresh collection so
/// the caller can diff before/after without guessing who mutated what.
library;

import '../../../models/midi_song.dart';

/// Builds [MidiNote]s from a flat `tick, dur, pitch, vel` quad vector.
///
/// Any trailing partial quad (a leftover element that can't form a full group
/// of four) is ignored, matching the parser's own tolerance of truncation.
List<MidiNote> notesFromFlat(List<int> flat) {
  final notes = <MidiNote>[];
  final quads = flat.length ~/ 4;
  for (var i = 0; i < quads; i++) {
    final base = i * 4;
    notes.add(
      MidiNote(
        tick: flat[base],
        dur: flat[base + 1],
        pitch: flat[base + 2],
        vel: flat[base + 3],
      ),
    );
  }
  return notes;
}

/// Inverse of [notesFromFlat]: a flat `tick, dur, pitch, vel` vector.
List<int> flatFromNotes(List<MidiNote> notes) {
  final flat = <int>[];
  for (final note in notes) {
    flat
      ..add(note.tick)
      ..add(note.dur)
      ..add(note.pitch)
      ..add(note.vel);
  }
  return flat;
}

/// True when any note whose pitch [matches] overlaps the half-open cell
/// `[cellStart, cellStart + cellTicks)`.
bool cellActive(
  List<MidiNote> notes, {
  required int cellStart,
  required int cellTicks,
  required bool Function(int pitch) matches,
}) {
  final cellEnd = cellStart + cellTicks;
  for (final note in notes) {
    if (matches(note.pitch) &&
        note.tick < cellEnd &&
        note.tick + note.dur > cellStart) {
      return true;
    }
  }
  return false;
}

/// Returns a NEW list with the cell toggled: if it is active, every matching
/// note overlapping the cell is removed; otherwise a single note is added.
///
/// The result is always sorted by tick, then pitch.
List<MidiNote> toggleCell(
  List<MidiNote> notes, {
  required int cellStart,
  required int cellTicks,
  required bool Function(int pitch) matches,
  required int addPitch,
  int vel = 100,
}) {
  final cellEnd = cellStart + cellTicks;
  final isActive = cellActive(
    notes,
    cellStart: cellStart,
    cellTicks: cellTicks,
    matches: matches,
  );

  final result = <MidiNote>[];
  if (!isActive) {
    result.add(
      MidiNote(tick: cellStart, dur: cellTicks, pitch: addPitch, vel: vel),
    );
  }
  for (final note in notes) {
    if (isActive &&
        matches(note.pitch) &&
        note.tick < cellEnd &&
        note.tick + note.dur > cellStart) {
      continue;
    }
    result.add(note);
  }
  result.sort((a, b) => a.tick != b.tick ? (a.tick - b.tick) : (a.pitch - b.pitch));
  return result;
}
