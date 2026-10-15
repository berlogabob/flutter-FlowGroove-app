import 'dart:convert';

import 'package:flowgroove/models/midi_pattern.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final pattern = MidiPattern(
    name: 'Rock',
    bars: 2,
    beatsPerBar: 4,
    stepsPerBeat: 4,
    hits: const [
      MidiHit(step: 0, note: 36, vel: 100),
      MidiHit(step: 4, note: 38, vel: 90),
    ],
  );

  SongLabEntry entry({Map<String, dynamic>? midi}) => SongLabEntry(
    id: 'e1',
    songId: 's1',
    type: LabEntryType.midi,
    title: 'Chorus drums',
    authorId: 'u1',
    createdAt: DateTime(2026, 10, 15, 12),
    updatedAt: DateTime(2026, 10, 15, 12),
    midi: midi,
  );

  test('MIDI payload round-trips through JSON and decodes as a pattern', () {
    final original = entry(midi: pattern.toJson());
    final json =
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>;
    final back = SongLabEntry.fromJson(json);

    expect(json['type'], 'midi');
    expect(json['midi'], pattern.toJson());
    expect(back.toJson(), original.toJson());
    expect(back.type, LabEntryType.midi);
    expect(back.midi, pattern.toJson());
    expect(back.pattern!.toJson(), pattern.toJson());
    expect(back.pattern!.totalSteps, 32);
    expect(back.pattern!.hits[1].step, 4);
    expect(back.pattern!.hits[1].note, 38);
    expect(back.pattern!.hits[1].vel, 90);
  });

  test('entry without MIDI omits the key and round-trips', () {
    final original = entry();
    final json = original.toJson();
    final back = SongLabEntry.fromJson(json);

    expect(json.containsKey('midi'), isFalse);
    expect(back.midi, isNull);
    expect(back.pattern, isNull);
    expect(back.toJson(), json);
  });

  test('legacy JSON without MIDI and explicit null payloads parse', () {
    final json = <String, dynamic>{
      'id': 'old-entry',
      'songId': 's1',
      'type': 'note',
      'body': 'Legacy note',
      'authorId': 'u1',
      'createdAt': '2026-07-16T12:00:00.000',
      'updatedAt': '2026-07-16T12:00:00.000',
    };
    final back = SongLabEntry.fromJson(json);

    expect(back.id, 'old-entry');
    expect(back.type, LabEntryType.note);
    expect(back.body, 'Legacy note');
    expect(back.createdAt, DateTime(2026, 7, 16, 12));
    expect(back.midi, isNull);
    expect(back.pattern, isNull);
    expect(back.toJson().containsKey('midi'), isFalse);

    final explicitNull = SongLabEntry.fromJson({...json, 'midi': null});
    expect(explicitNull.midi, isNull);
    expect(explicitNull.pattern, isNull);
    expect(explicitNull.toJson().containsKey('midi'), isFalse);
  });

  test('copyWith adds, preserves and replaces MIDI payloads', () {
    final original = entry();
    final added = original.copyWith(midi: pattern.toJson());
    expect(original.midi, isNull);
    expect(added.pattern!.toJson(), pattern.toJson());

    final edited = added.copyWith(title: 'Updated drums');
    expect(edited.title, 'Updated drums');
    expect(edited.midi, pattern.toJson());
    expect(edited.id, added.id);
    expect(edited.songId, added.songId);
    expect(edited.type, LabEntryType.midi);
    expect(edited.authorId, added.authorId);
    expect(edited.createdAt, added.createdAt);

    final replacement = MidiPattern(
      name: 'Waltz',
      bars: 1,
      beatsPerBar: 3,
      stepsPerBeat: 4,
      hits: const [MidiHit(step: 0, note: 36, vel: 80)],
    );
    final replaced = edited.copyWith(midi: replacement.toJson());
    expect(replaced.pattern!.toJson(), replacement.toJson());
    expect(edited.pattern!.toJson(), pattern.toJson());
  });

  test('MIDI is appended and existing enum names and indexes are stable', () {
    const oldNames = [
      'note',
      'idea',
      'decision',
      'experiment',
      'problem',
      'task',
      'rehearsalNote',
      'recording',
      'versionChange',
      'reference',
    ];
    expect(LabEntryType.values.map((type) => type.name), [...oldNames, 'midi']);
    for (var i = 0; i < oldNames.length; i++) {
      expect(LabEntryType.parse(oldNames[i]).index, i);
    }
    expect(LabEntryType.values.last, LabEntryType.midi);
    expect(LabEntryType.parse('midi'), LabEntryType.midi);
    expect(LabEntryType.parse('unknown'), LabEntryType.note);
    expect(LabEntryType.parse(null), LabEntryType.note);
    expect(SongLabEntry.fromJson({'type': 'unknown'}).type, LabEntryType.note);
  });
}
