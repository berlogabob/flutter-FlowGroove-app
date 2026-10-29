import 'dart:convert';

import 'package:flowgroove/models/metronome_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final session = MetronomeSession(
    id: 'session-1',
    startedAt: DateTime.utc(2026, 10, 15, 12),
    endedAt: DateTime.utc(2026, 10, 15, 12, 2),
    presetId: 'preset-1',
    songId: 'song-1',
    setlistId: 'setlist-1',
    startBpm: 100,
    endBpm: 120,
    elapsedSeconds: 120,
    barCount: 55,
    usedTapTempo: true,
    usedTempoRamp: true,
    usedCountIn: true,
    completion: MetronomeSessionCompletion.stopped,
  );

  test('session with a MIDI entry round-trips through JSON', () {
    final linked = session.copyWith(midiEntryId: 'entry-1');
    final json =
        jsonDecode(jsonEncode(linked.toJson())) as Map<String, dynamic>;
    final back = MetronomeSession.fromJson(json);

    expect(json['midiEntryId'], 'entry-1');
    expect(back.midiEntryId, 'entry-1');
    expect(back.toJson(), linked.toJson());
    expect(back.toJson(), {...session.toJson(), 'midiEntryId': 'entry-1'});
  });

  test('session without a MIDI entry omits the key', () {
    expect(session.midiEntryId, isNull);
    expect(session.toJson().containsKey('midiEntryId'), isFalse);
    expect(MetronomeSession.fromJson(session.toJson()).midiEntryId, isNull);
  });

  test('old JSON without the key and explicit null remain readable', () {
    final json = <String, dynamic>{
      'id': 'legacy-session',
      'startedAt': '2026-07-16T12:00:00.000Z',
      'startBpm': 90,
      'elapsedSeconds': 60,
      'completion': 'stopped',
    };
    for (final value in [
      json,
      {...json, 'midiEntryId': null},
    ]) {
      final back = MetronomeSession.fromJson(value);
      expect(back.midiEntryId, isNull);
      expect(back.id, 'legacy-session');
      expect(back.startedAt, DateTime.utc(2026, 7, 16, 12));
      expect(back.startBpm, 90);
      expect(back.elapsedSeconds, 60);
      expect(back.completion, MetronomeSessionCompletion.stopped);
      expect(back.toJson().containsKey('midiEntryId'), isFalse);
    }
  });

  test('copyWith adds, preserves and replaces the MIDI link', () {
    final linked = session.copyWith(midiEntryId: 'entry-1');
    final edited = linked.copyWith(endBpm: 140, usedTapTempo: false);
    final replaced = edited.copyWith(midiEntryId: 'entry-2');

    expect(session.midiEntryId, isNull);
    expect(linked.toJson(), {...session.toJson(), 'midiEntryId': 'entry-1'});
    expect(edited.toJson(), {
      ...linked.toJson(),
      'endBpm': 140,
      'usedTapTempo': false,
    });
    expect(replaced.toJson(), {...edited.toJson(), 'midiEntryId': 'entry-2'});
    expect(linked.copyWith().toJson(), linked.toJson());
  });
}
