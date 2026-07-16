import 'package:flowgroove/models/canonical_song.dart';
import 'package:flowgroove/models/section.dart';
import 'package:flowgroove/utils/canonical_import.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canonicalToSong (#59)', () {
    final canonical = CanonicalSong(
      id: 'canon-1',
      title: 'Hey Joe',
      artist: 'Jimi Hendrix',
      album: 'Are You Experienced',
      baseKey: 'Em',
      baseBpm: 82,
      baseSections: [
        Section(id: 'base-s1', name: 'Verse', duration: 4, chordChart: '[Em]x'),
      ],
      musicBrainzId: 'mb-123',
      isrc: 'USAA00000001',
    );

    test('maps base arrangement into original AND our fields', () {
      final song = canonicalToSong(canonical);

      expect(song.title, 'Hey Joe');
      expect(song.artist, 'Jimi Hendrix');
      expect(song.album, 'Are You Experienced');
      expect(song.originalKey, 'Em');
      expect(song.ourKey, 'Em');
      expect(song.originalBPM, 82);
      expect(song.ourBPM, 82);
      expect(song.canonicalSongId, 'canon-1');
      expect(song.musicbrainzId, 'mb-123');
      expect(song.isrc, 'USAA00000001');
      expect(song.isFromMusicBrainz, isTrue);
    });

    test('clones sections with fresh ids', () {
      final song = canonicalToSong(canonical);

      expect(song.sections, hasLength(1));
      expect(song.sections.single.name, 'Verse');
      expect(song.sections.single.chordChart, '[Em]x');
      expect(song.sections.single.id, isNot('base-s1'));
    });

    test('two imports produce distinct song and section ids', () {
      final a = canonicalToSong(canonical);
      final b = canonicalToSong(canonical);
      expect(a.id, isNot(b.id));
      expect(a.sections.single.id, isNot(b.sections.single.id));
    });
  });
}
