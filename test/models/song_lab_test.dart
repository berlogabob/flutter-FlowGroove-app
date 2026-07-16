import 'package:flowgroove/models/song_lab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Song Lab models (#66)', () {
    test('SongLabEntry round-trips through JSON', () {
      final entry = SongLabEntry(
        id: 'e1',
        songId: 's1',
        bandId: 'b1',
        type: LabEntryType.decision,
        title: 'Half-time chorus',
        body: 'We play the last chorus half-time.',
        sectionId: 'sec-1',
        status: 'active',
        tags: const ['arrangement'],
        authorId: 'u1',
        visibility: 'band',
        createdAt: DateTime(2026, 7, 16, 12),
        updatedAt: DateTime(2026, 7, 16, 12),
        attachmentIds: const ['a1'],
      );

      final back = SongLabEntry.fromJson(entry.toJson());
      expect(back.id, 'e1');
      expect(back.type, LabEntryType.decision);
      expect(back.status, 'active');
      expect(back.sectionId, 'sec-1');
      expect(back.tags, ['arrangement']);
      expect(back.attachmentIds, ['a1']);
      expect(back.createdAt, DateTime(2026, 7, 16, 12));
    });

    test('unknown entry type parses to note, unknown status to todo', () {
      expect(LabEntryType.parse('hologram'), LabEntryType.note);
      expect(SongTaskStatus.parse('later'), SongTaskStatus.todo);
    });

    test('SongTask round-trips and knows openness', () {
      final task = SongTask(
        id: 't1',
        songId: 's1',
        title: 'Learn the solo',
        assignedToUserId: 'u2',
        status: SongTaskStatus.doing,
        dueAt: DateTime(2026, 8, 1),
        priority: 1,
        createdAt: DateTime(2026, 7, 16),
        updatedAt: DateTime(2026, 7, 16),
      );
      final back = SongTask.fromJson(task.toJson());
      expect(back.status, SongTaskStatus.doing);
      expect(back.dueAt, DateTime(2026, 8, 1));
      expect(back.isOpen, isTrue);
      expect(back.copyWith(status: SongTaskStatus.done).isOpen, isFalse);
    });

    test('SongVersion round-trips with snapshots and current flag', () {
      final v = SongVersion(
        id: 'v1',
        songId: 's1',
        name: 'v0.3 Acoustic',
        status: 'current',
        bpm: 96,
        key: 'Am',
        structureSnapshot: 'Verse ×2 · Chorus',
        lyricsSnapshot: '{title: X}\n[Am]la',
        notes: 'slower intro',
        createdAt: DateTime(2026, 7, 16),
      );
      final back = SongVersion.fromJson(v.toJson());
      expect(back.isCurrent, isTrue);
      expect(back.bpm, 96);
      expect(back.lyricsSnapshot, contains('[Am]la'));
    });
  });
}
