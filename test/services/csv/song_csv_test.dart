/// Tests for CSV parsing and serialization.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/models/song.dart';
import 'package:flutter_repsync_app/models/section.dart';
import 'package:flutter_repsync_app/models/link.dart';
import 'package:flutter_repsync_app/services/csv/song_csv_parser.dart';
import 'package:flutter_repsync_app/services/csv/song_csv_serializer.dart';
import 'package:flutter_repsync_app/services/csv/song_csv_schema.dart';

void main() {
  group('SongCsvSchema', () {
    group('parseKeyString', () {
      test('parses C major', () {
        final result = SongCsvSchema.parseKeyString('C');
        expect(result['base'], equals('C'));
        expect(result['accidental'], isNull);
        expect(result['scale'], equals('major'));
      });

      test('parses C# minor', () {
        final result = SongCsvSchema.parseKeyString('C#m');
        expect(result['base'], equals('C'));
        expect(result['accidental'], equals('#'));
        expect(result['scale'], equals('minor'));
      });

      test('parses Bb major', () {
        final result = SongCsvSchema.parseKeyString('Bb');
        expect(result['base'], equals('B'));
        expect(result['accidental'], equals('b'));
        expect(result['scale'], equals('major'));
      });

      test('parses Am', () {
        final result = SongCsvSchema.parseKeyString('Am');
        expect(result['base'], equals('A'));
        expect(result['accidental'], isNull);
        expect(result['scale'], equals('minor'));
      });
    });

    group('buildKeyString', () {
      test('builds C major', () {
        final result = SongCsvSchema.buildKeyString(
          base: 'C',
          accidental: null,
          scale: 'major',
        );
        expect(result, equals('C'));
      });

      test('builds C# minor', () {
        final result = SongCsvSchema.buildKeyString(
          base: 'C',
          accidental: '#',
          scale: 'minor',
        );
        expect(result, equals('C#m'));
      });

      test('builds Bb major', () {
        final result = SongCsvSchema.buildKeyString(
          base: 'B',
          accidental: 'b',
          scale: 'major',
        );
        expect(result, equals('Bb'));
      });

      test('builds Bbm minor', () {
        final result = SongCsvSchema.buildKeyString(
          base: 'B',
          accidental: 'b',
          scale: 'minor',
        );
        expect(result, equals('Bbm'));
      });
    });
  });

  group('SongCsvSerializer', () {
    test('serializes basic song to CSV', () {
      final serializer = SongCsvSerializer();
      final song = Song(
        id: 'test-1',
        title: 'Test Song',
        artist: 'Test Artist',
        originalKey: 'C',
        originalBPM: 120,
        ourKey: 'D',
        ourBPM: 130,
        links: [],
        notes: 'Test notes',
        tags: ['rock', 'live'],
        bandId: null,
        spotifyUrl: null,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 2),
        accentBeats: 4,
        regularBeats: 1,
        beatModes: [],
        sections: [],
      );

      final csv = serializer.serialize([song]);
      
      expect(csv, contains('Test Song'));
      expect(csv, contains('Test Artist'));
      expect(csv, contains('rock,live'));
    });

    test('serializes song with split key format', () {
      final serializer = SongCsvSerializer();
      final song = Song(
        id: 'test-split-key',
        title: 'Song With Split Keys',
        artist: 'Artist',
        originalKey: 'C#m',
        originalBPM: 120,
        ourKey: 'Bb',
        ourBPM: 130,
        links: [],
        notes: null,
        tags: [],
        bandId: null,
        spotifyUrl: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        accentBeats: 4,
        regularBeats: 1,
        beatModes: [],
        sections: [],
      );

      final csv = serializer.serialize([song]);

      // Check split format headers
      expect(csv, contains('originalKeyBase'));
      expect(csv, contains('originalKeyAccidental'));
      expect(csv, contains('originalKeyScale'));

      // Check values - C#m should be split into C, #, minor
      expect(csv, contains(',C,')); // original base
      expect(csv, contains(',#,')); // original accidental
      expect(csv, contains(',minor,')); // original scale
    });

    test('serializes song with sections', () {
      final serializer = SongCsvSerializer();
      final song = Song(
        id: 'test-2',
        title: 'Song With Sections',
        artist: 'Artist',
        originalKey: null,
        originalBPM: null,
        ourKey: null,
        ourBPM: null,
        links: [],
        notes: null,
        tags: [],
        bandId: null,
        spotifyUrl: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        accentBeats: 4,
        regularBeats: 1,
        beatModes: [],
        sections: [
          Section(
            id: 'sec-1',
            name: 'Intro',
            notes: '',
            duration: 4,
            colorValue: 0xFF42A5F5,
          ),
          Section(
            id: 'sec-2',
            name: 'Verse',
            notes: 'Chords: Am G C',
            duration: 8,
            colorValue: 0xFF66BB6A,
          ),
        ],
      );

      final csv = serializer.serialize([song]);
      
      expect(csv, contains('section_1_name'));
      expect(csv, contains('Intro'));
      expect(csv, contains('Verse'));
    });

    test('serializes song with links', () {
      final serializer = SongCsvSerializer();
      final song = Song(
        id: 'test-3',
        title: 'Song With Links',
        artist: 'Artist',
        originalKey: null,
        originalBPM: null,
        ourKey: null,
        ourBPM: null,
        links: [
          Link(
            type: 'youtube_original',
            url: 'https://youtube.com/watch?v=test',
            title: 'Official Video',
          ),
          Link(
            type: 'spotify',
            url: 'https://open.spotify.com/track/test',
            title: 'Spotify',
          ),
        ],
        notes: null,
        tags: [],
        bandId: null,
        spotifyUrl: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        accentBeats: 4,
        regularBeats: 1,
        beatModes: [],
        sections: [],
      );

      final csv = serializer.serialize([song]);
      
      expect(csv, contains('link_1_url'));
      expect(csv, contains('youtube.com'));
    });
  });

  group('SongCsvParser', () {
    test('parses basic CSV to songs', () {
      final parser = SongCsvParser();
      final csv = '''
title,artist,originalKey,originalBPM,ourKey,ourBPM,notes,tags,accentBeats,regularBeats
Test Song,Test Artist,C,120,D,130,Test notes,"rock,live",4,1
''';

      final result = parser.parse(csv);

      expect(result.errors, isEmpty);
      expect(result.successful, hasLength(1));
      expect(result.successful.first.title, equals('Test Song'));
      expect(result.successful.first.artist, equals('Test Artist'));
      expect(result.successful.first.originalKey, equals('C'));
      expect(result.successful.first.originalBPM, equals(120));
      expect(result.successful.first.ourKey, equals('D'));
      expect(result.successful.first.ourBPM, equals(130));
      expect(result.successful.first.notes, equals('Test notes'));
      expect(result.successful.first.tags, contains('rock'));
      expect(result.successful.first.tags, contains('live'));
    });

    test('parses CSV with split key format', () {
      final parser = SongCsvParser();
      final csv = '''
title,artist,originalKeyBase,originalKeyAccidental,originalKeyScale,originalBPM,ourKeyBase,ourKeyAccidental,ourKeyScale,ourBPM
Test Song,Test Artist,C,#,minor,120,B,b,major,130
''';

      final result = parser.parse(csv);

      expect(result.errors, isEmpty);
      expect(result.successful, hasLength(1));
      expect(result.successful.first.title, equals('Test Song'));
      expect(result.successful.first.originalKey, equals('C#m'));
      expect(result.successful.first.ourKey, equals('Bb'));
    });

    test('returns error for missing required fields', () {
      final parser = SongCsvParser();
      final csv = '''
title,artist
,Test Artist
''';

      final result = parser.parse(csv);
      
      expect(result.errors, isNotEmpty);
      expect(result.successful, isEmpty);
    });

    test('returns error for missing required headers', () {
      final parser = SongCsvParser();
      final csv = '''
title
Test Song
''';

      final result = parser.parse(csv);
      
      expect(result.errors, isNotEmpty);
      expect(result.errors.first, contains('Missing required header'));
    });

    test('parses CSV with sections', () {
      final parser = SongCsvParser();
      final csv = '''
title,artist,section_1_name,section_1_duration,section_2_name,section_2_duration
Test Song,Artist,Intro,4,Verse,8
''';

      final result = parser.parse(csv);
      
      expect(result.errors, isEmpty);
      expect(result.successful, hasLength(1));
      expect(result.successful.first.sections, hasLength(2));
      expect(result.successful.first.sections[0].name, equals('Intro'));
      expect(result.successful.first.sections[0].duration, equals(4));
      expect(result.successful.first.sections[1].name, equals('Verse'));
    });

    test('parses CSV with links', () {
      final parser = SongCsvParser();
      final csv = '''
title,artist,link_1_url,link_1_title,link_1_type
Test Song,Artist,https://youtube.com/test,Official Video,youtube_original
''';

      final result = parser.parse(csv);
      
      expect(result.errors, isEmpty);
      expect(result.successful, hasLength(1));
      expect(result.successful.first.links, hasLength(1));
      expect(result.successful.first.links.first.url, contains('youtube.com'));
      expect(result.successful.first.links.first.title, equals('Official Video'));
      expect(result.successful.first.links.first.type, equals('youtube_original'));
    });

    test('parses CSV with beat modes', () {
      final parser = SongCsvParser();
      final csv = '''
title,artist,accentBeats,regularBeats,beatMode_0_0,beatMode_0_1,beatMode_1_0
Test Song,Artist,4,2,accent,normal,normal
''';

      final result = parser.parse(csv);
      
      expect(result.errors, isEmpty);
      expect(result.successful, hasLength(1));
      expect(result.successful.first.accentBeats, equals(4));
      expect(result.successful.first.regularBeats, equals(2));
      expect(result.successful.first.beatModes[0][0].name, equals('accent'));
      expect(result.successful.first.beatModes[0][1].name, equals('normal'));
      expect(result.successful.first.beatModes[1][0].name, equals('normal'));
    });

    test('handles empty CSV', () {
      final parser = SongCsvParser();
      final csv = '';

      final result = parser.parse(csv);
      
      expect(result.errors, isNotEmpty);
      expect(result.errors.first, contains('empty'));
    });

    test('handles multiple songs', () {
      final parser = SongCsvParser();
      final csv = '''
title,artist
Song 1,Artist 1
Song 2,Artist 2
Song 3,Artist 3
''';

      final result = parser.parse(csv);
      
      expect(result.errors, isEmpty);
      expect(result.successful, hasLength(3));
      expect(result.successful[0].title, equals('Song 1'));
      expect(result.successful[1].title, equals('Song 2'));
      expect(result.successful[2].title, equals('Song 3'));
    });
  });

  group('Round-trip', () {
    test('serialize then parse preserves data', () {
      final serializer = SongCsvSerializer();
      final parser = SongCsvParser();
      
      final originalSong = Song(
        id: 'test-roundtrip',
        title: 'Round Trip Song',
        artist: 'Test Artist',
        originalKey: 'C',
        originalBPM: 120,
        ourKey: 'D',
        ourBPM: 130,
        links: [
          Link(
            type: 'youtube_original',
            url: 'https://youtube.com/test',
            title: 'Video',
          ),
        ],
        notes: 'Test notes',
        tags: ['rock'],
        bandId: null,
        spotifyUrl: null,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 2),
        accentBeats: 4,
        regularBeats: 1,
        beatModes: [],
        sections: [
          Section(
            id: 'sec-1',
            name: 'Intro',
            notes: '',
            duration: 4,
            colorValue: 0xFF42A5F5,
          ),
        ],
      );

      // Serialize
      final csv = serializer.serialize([originalSong]);
      
      // Parse
      final result = parser.parse(csv);
      
      expect(result.errors, isEmpty);
      expect(result.successful, hasLength(1));
      
      final parsedSong = result.successful.first;
      expect(parsedSong.title, equals(originalSong.title));
      expect(parsedSong.artist, equals(originalSong.artist));
      expect(parsedSong.originalKey, equals(originalSong.originalKey));
      expect(parsedSong.originalBPM, equals(originalSong.originalBPM));
      expect(parsedSong.ourKey, equals(originalSong.ourKey));
      expect(parsedSong.ourBPM, equals(originalSong.ourBPM));
      expect(parsedSong.notes, equals(originalSong.notes));
      expect(parsedSong.tags, equals(originalSong.tags));
      expect(parsedSong.sections, hasLength(1));
      expect(parsedSong.sections.first.name, equals('Intro'));
      expect(parsedSong.links, hasLength(1));
      expect(parsedSong.links.first.url, contains('youtube.com'));
    });
  });
}
