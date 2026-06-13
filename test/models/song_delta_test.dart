import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/models/beat_mode.dart';
import 'package:flowgroove/models/canonical_song.dart';
import 'package:flowgroove/models/link.dart';
import 'package:flowgroove/models/section.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/models/song_delta.dart';

void main() {
  group('SongDelta', () {
    final canonical = CanonicalSong(
      id: 'canonical-1',
      title: 'Bohemian Rhapsody',
      artist: 'Queen',
      album: 'A Night at the Opera',
      durationMs: 354000,
      musicBrainzId: 'mb-id',
      isrc: 'isrc-id',
      normalizedTitle: 'bohemian rhapsody',
      normalizedArtist: 'queen',
      baseKey: 'Bb',
      baseBpm: 72,
      baseSections: [Section(id: 'intro', name: 'Intro', duration: 2)],
      baseAccentBeats: 6,
      baseRegularBeats: 1,
      baseBeatModes: const [
        [BeatMode.accent],
        [BeatMode.normal],
      ],
      baseLinks: [
        Link(type: Link.typeYoutubeOriginal, url: 'https://original.test'),
      ],
      createdAt: DateTime(2026, 5, 11),
      updatedAt: DateTime(2026, 5, 13),
    );

    test('compute stores only fields changed from canonical defaults', () {
      final song = Song(
        id: 'library-1',
        title: canonical.title,
        artist: canonical.artist,
        originalKey: canonical.baseKey,
        originalBPM: canonical.baseBpm,
        ourKey: 'C',
        ourBPM: 76,
        notes: 'Start soft.',
        defaultTuningPresetId: 'guitar:drop_d',
        tags: const ['ready'],
        links: canonical.baseLinks,
        sections: canonical.baseSections,
        accentBeats: canonical.baseAccentBeats,
        regularBeats: canonical.baseRegularBeats,
        beatModes: canonical.baseBeatModes,
        createdAt: DateTime(2026, 5, 12),
        updatedAt: DateTime(2026, 5, 12),
      );

      final delta = SongDelta.compute(canonical: canonical, song: song);

      expect(delta.values.keys, {
        SongDeltaField.ourKey,
        SongDeltaField.ourBPM,
        SongDeltaField.notes,
        SongDeltaField.tags,
        SongDeltaField.defaultTuningPresetId,
      });
      expect(delta.ourKey, 'C');
      expect(delta.ourBPM, 76);
      expect(delta.notes, 'Start soft.');
      expect(delta.tags, ['ready']);
      expect(delta.defaultTuningPresetId, 'guitar:drop_d');
    });

    test('applyTo produces the existing Song read model', () {
      final delta = SongDelta(
        values: {
          SongDeltaField.ourKey: 'C',
          SongDeltaField.ourBPM: 76,
          SongDeltaField.notes: 'Start soft.',
          SongDeltaField.tags: ['ready'],
          SongDeltaField.accentBeats: 4,
          SongDeltaField.defaultTuningPresetId: 'custom-live',
        },
      );

      final merged = delta.applyTo(
        canonical: canonical,
        librarySongId: 'library-1',
        createdAt: DateTime(2026, 5, 12),
        updatedAt: DateTime(2026, 5, 14),
      );

      expect(merged.id, 'library-1');
      expect(merged.title, canonical.title);
      expect(merged.artist, canonical.artist);
      expect(merged.originalKey, 'Bb');
      expect(merged.originalBPM, 72);
      expect(merged.ourKey, 'C');
      expect(merged.ourBPM, 76);
      expect(merged.notes, 'Start soft.');
      expect(merged.tags, ['ready']);
      expect(merged.links.single.url, 'https://original.test');
      expect(merged.sections.single.name, 'Intro');
      expect(merged.accentBeats, 4);
      expect(merged.defaultTuningPresetId, 'custom-live');
      expect(merged.regularBeats, 1);
      expect(merged.canonicalSongId, 'canonical-1');
      expect(merged.isFromMusicBrainz, isTrue);
    });

    test('fromJson ignores unsupported fields and restores typed lists', () {
      final delta = SongDelta.fromJson({
        SongDeltaField.links: [
          {'type': Link.typeOther, 'url': 'https://lyrics.test'},
        ],
        SongDeltaField.sections: [
          {'id': 'chorus', 'name': 'Chorus', 'duration': 4},
        ],
        SongDeltaField.beatModes: {'0-0': BeatMode.accent.name},
        'unknown': 'ignored',
      });

      expect(delta.values.containsKey('unknown'), isFalse);
      expect(delta.links!.single.type, Link.typeOther);
      expect(delta.sections!.single.name, 'Chorus');
      expect(delta.beatModes!.single.single, BeatMode.accent);
    });
  });
}
