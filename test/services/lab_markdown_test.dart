import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/services/export/lab_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final song = Song(
    id: 's1',
    title: 'Hey Joe',
    artist: 'Jimi Hendrix',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  SongLabEntry entry(
    LabEntryType type, {
    String? title,
    String? body,
    String? status,
  }) => SongLabEntry(
    id: '${type.name}-${title ?? ''}',
    songId: 's1',
    type: type,
    title: title,
    body: body,
    status: status,
    authorId: 'u1',
    createdAt: DateTime(2026, 7, 10),
    updatedAt: DateTime(2026, 7, 10),
  );

  test('buildLabMarkdown assembles all sections (#70)', () {
    final md = buildLabMarkdown(
      song: song,
      entries: [
        entry(
          LabEntryType.decision,
          title: 'Half-time chorus',
          body: 'last chorus half-time',
          status: 'active',
        ),
        entry(
          LabEntryType.decision,
          title: 'Old idea',
          status: 'superseded',
        ),
        entry(LabEntryType.note, body: 'riff idea'),
      ],
      tasks: [
        SongTask(
          id: 't1',
          songId: 's1',
          title: 'Learn the solo',
          dueAt: DateTime(2026, 8, 1),
          createdAt: DateTime(2026, 7, 1),
          updatedAt: DateTime(2026, 7, 1),
        ),
        SongTask(
          id: 't2',
          songId: 's1',
          title: 'Done thing',
          status: SongTaskStatus.done,
          createdAt: DateTime(2026, 7, 1),
          updatedAt: DateTime(2026, 7, 1),
        ),
      ],
      versions: [
        SongVersion(
          id: 'v1',
          songId: 's1',
          name: 'v0.3 Acoustic',
          status: 'current',
          key: 'Em',
          bpm: 82,
          createdAt: DateTime(2026, 7, 12),
        ),
      ],
    );

    expect(md, contains('# Hey Joe — Lab history'));
    expect(md, contains('## Active decisions'));
    expect(md, contains('**Half-time chorus** — last chorus half-time'));
    // Superseded decisions stay out of Active decisions (but remain in the
    // timeline below).
    final beforeTimeline = md.split('## Timeline').first;
    expect(beforeTimeline, isNot(contains('Old idea')));
    expect(md.split('## Timeline').last, contains('Old idea'));
    expect(md, contains('## Open tasks'));
    expect(md, contains('- [ ] Learn the solo (due 2026-08-01)'));
    expect(md, isNot(contains('- [ ] Done thing')));
    expect(md, contains('## Versions'));
    expect(md, contains('**v0.3 Acoustic** — current · Em · 82 BPM'));
    expect(md, contains('## Timeline'));
    expect(md, contains('riff idea'));
  });

  test('empty lab still produces a valid header-only document', () {
    final md = buildLabMarkdown(
      song: song,
      entries: const [],
      tasks: const [],
      versions: const [],
    );
    expect(md, contains('# Hey Joe — Lab history'));
    expect(md, isNot(contains('## Active decisions')));
    expect(md, isNot(contains('## Timeline')));
  });
}
