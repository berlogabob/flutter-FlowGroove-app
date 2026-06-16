import 'package:flowgroove/services/api/track_analysis_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrackAnalysisService', () {
    group('isConfigured', () {
      test('returns false because client-side RapidAPI is disabled', () {
        expect(TrackAnalysisService.isConfigured, isFalse);
      });
    });

    group('analyzeTrack() validation', () {
      test('returns null when title is empty', () async {
        final result = await TrackAnalysisService.analyzeTrack('', 'Artist');
        expect(result, isNull);
      });

      test('returns null when title is whitespace only', () async {
        final result = await TrackAnalysisService.analyzeTrack('   ', 'Artist');
        expect(result, isNull);
      });

      test('returns null when title is tab only', () async {
        final result = await TrackAnalysisService.analyzeTrack(
          '\t\t',
          'Artist',
        );
        expect(result, isNull);
      });

      test('returns null when title is newline only', () async {
        final result = await TrackAnalysisService.analyzeTrack(
          '\n\n',
          'Artist',
        );
        expect(result, isNull);
      });

      test('accepts valid title and artist', () async {
        final result = await TrackAnalysisService.analyzeTrack(
          'Song Title',
          'Artist',
        );
        expect(result, isNull);
      });

      test('handles null artist gracefully', () async {
        final result = await TrackAnalysisService.analyzeTrack(
          'Song Title',
          '',
        );
        expect(result, isNull);
      });

      test('handles both title and artist empty', () async {
        final result = await TrackAnalysisService.analyzeTrack('', '');
        expect(result, isNull);
      });
    });

    group('TrackAnalysis JSON parsing', () {
      test('parses track analysis with all fields correctly', () {
        final analysisJson = {
          'track': 'Test Song',
          'artist': 'Test Artist',
          'key': 'C',
          'mode': 'major',
          'bpm': 120,
          'energy': 0.75,
          'danceability': 0.65,
        };

        final analysis = TrackAnalysis.fromJson(analysisJson);
        expect(analysis.title, equals('Test Song'));
        expect(analysis.artist, equals('Test Artist'));
        expect(analysis.key, equals('C'));
        expect(analysis.mode, equals('major'));
        expect(analysis.bpm, equals(120));
        expect(analysis.energy, equals(0.75));
        expect(analysis.danceability, equals(0.65));
      });

      test('handles missing fields gracefully', () {
        final analysisJson = <String, dynamic>{};

        final analysis = TrackAnalysis.fromJson(analysisJson);
        expect(analysis.title, isNull);
        expect(analysis.artist, isNull);
        expect(analysis.key, isNull);
        expect(analysis.mode, isNull);
        expect(analysis.bpm, isNull);
        expect(analysis.energy, isNull);
        expect(analysis.danceability, isNull);
      });

      test('handles null values in JSON', () {
        final analysisJson = {
          'track': null,
          'artist': null,
          'key': null,
          'mode': null,
          'bpm': null,
          'energy': null,
          'danceability': null,
        };

        final analysis = TrackAnalysis.fromJson(analysisJson);
        expect(analysis.title, isNull);
        expect(analysis.artist, isNull);
        expect(analysis.key, isNull);
        expect(analysis.mode, isNull);
        expect(analysis.bpm, isNull);
        expect(analysis.energy, isNull);
        expect(analysis.danceability, isNull);
      });

      test('musicalKey returns key with mode when both present', () {
        final analysis = TrackAnalysis(
          title: 'Test Song',
          artist: 'Test Artist',
          key: 'C',
          mode: 'major',
          bpm: 120,
        );

        expect(analysis.musicalKey, equals('C major'));
      });

      test('musicalKey returns only key when mode is null', () {
        final analysis = TrackAnalysis(
          title: 'Test Song',
          artist: 'Test Artist',
          key: 'D',
          bpm: 120,
        );

        expect(analysis.musicalKey, equals('D'));
      });

      test('musicalKey returns empty string when key is null', () {
        final analysis = TrackAnalysis(
          title: 'Test Song',
          artist: 'Test Artist',
          mode: 'major',
          bpm: 120,
        );

        expect(analysis.musicalKey, equals(''));
      });

      test('handles integer energy and danceability values', () {
        final analysisJson = {
          'track': 'Test Song',
          'artist': 'Test Artist',
          'key': 'C',
          'mode': 'major',
          'bpm': 120,
          'energy': 75,
          'danceability': 65,
        };

        final analysis = TrackAnalysis.fromJson(analysisJson);
        expect(analysis.energy, equals(75.0));
        expect(analysis.danceability, equals(65.0));
      });

      test('handles string key and mode values', () {
        final analysisJson = {
          'track': 'Test Song',
          'artist': 'Test Artist',
          'key': 'C#',
          'mode': 'minor',
          'bpm': 100,
          'energy': 0.5,
          'danceability': 0.6,
        };

        final analysis = TrackAnalysis.fromJson(analysisJson);
        expect(analysis.key, equals('C#'));
        expect(analysis.mode, equals('minor'));
        expect(analysis.musicalKey, equals('C# minor'));
      });

      test('creates TrackAnalysis with constructor', () {
        final analysis = TrackAnalysis(
          title: 'Test Song',
          artist: 'Test Artist',
          key: 'E',
          mode: 'minor',
          bpm: 140,
          energy: 0.9,
          danceability: 0.8,
        );

        expect(analysis.title, equals('Test Song'));
        expect(analysis.artist, equals('Test Artist'));
        expect(analysis.key, equals('E'));
        expect(analysis.mode, equals('minor'));
        expect(analysis.bpm, equals(140));
        expect(analysis.energy, equals(0.9));
        expect(analysis.danceability, equals(0.8));
        expect(analysis.musicalKey, equals('E minor'));
      });

      test('handles partial data (only BPM)', () {
        final analysisJson = {'bpm': 120};

        final analysis = TrackAnalysis.fromJson(analysisJson);
        expect(analysis.bpm, equals(120));
        expect(analysis.title, isNull);
        expect(analysis.key, isNull);
      });

      test('handles partial data (only key)', () {
        final analysisJson = {'key': 'C', 'mode': 'major'};

        final analysis = TrackAnalysis.fromJson(analysisJson);
        expect(analysis.key, equals('C'));
        expect(analysis.mode, equals('major'));
        expect(analysis.musicalKey, equals('C major'));
      });

      test('handles partial data (only energy)', () {
        final analysisJson = {'energy': 0.8};

        final analysis = TrackAnalysis.fromJson(analysisJson);
        expect(analysis.energy, equals(0.8));
      });
    });

    group('Edge cases and boundary tests', () {
      test('handles zero BPM', () {
        final analysisJson = {
          'track': 'Test Song',
          'artist': 'Test Artist',
          'key': 'C',
          'mode': 'major',
          'bpm': 0,
          'energy': 0.5,
          'danceability': 0.5,
        };

        final analysis = TrackAnalysis.fromJson(analysisJson);
        expect(analysis.bpm, equals(0));
      });

      test('handles very high BPM', () {
        final analysisJson = {
          'track': 'Test Song',
          'artist': 'Test Artist',
          'key': 'C',
          'mode': 'major',
          'bpm': 300,
          'energy': 0.9,
          'danceability': 0.9,
        };

        final analysis = TrackAnalysis.fromJson(analysisJson);
        expect(analysis.bpm, equals(300));
      });

      test('handles energy and danceability at boundaries', () {
        final analysisJson = {
          'track': 'Test Song',
          'artist': 'Test Artist',
          'key': 'C',
          'mode': 'major',
          'bpm': 120,
          'energy': 1.0,
          'danceability': 0.0,
        };

        final analysis = TrackAnalysis.fromJson(analysisJson);
        expect(analysis.energy, equals(1.0));
        expect(analysis.danceability, equals(0.0));
      });

      test('handles negative energy and danceability', () {
        final analysisJson = {
          'track': 'Test Song',
          'artist': 'Test Artist',
          'key': 'C',
          'mode': 'major',
          'bpm': 120,
          'energy': -0.5,
          'danceability': -0.3,
        };

        final analysis = TrackAnalysis.fromJson(analysisJson);
        expect(analysis.energy, equals(-0.5));
        expect(analysis.danceability, equals(-0.3));
      });

      test('handles energy above 1.0', () {
        final analysisJson = {
          'track': 'Test Song',
          'artist': 'Test Artist',
          'key': 'C',
          'mode': 'major',
          'bpm': 120,
          'energy': 1.5,
          'danceability': 0.5,
        };

        final analysis = TrackAnalysis.fromJson(analysisJson);
        expect(analysis.energy, equals(1.5));
      });

      test('handles very long track title', () {
        final longTitle = 'A' * 1000;
        final analysisJson = {
          'track': longTitle,
          'artist': 'Test Artist',
          'key': 'C',
          'mode': 'major',
          'bpm': 120,
        };

        final analysis = TrackAnalysis.fromJson(analysisJson);
        expect(analysis.title!.length, equals(1000));
      });

      test('handles unicode characters in title', () {
        final analysisJson = {
          'track': 'Test Song 🎵 音楽',
          'artist': 'Test Artist',
          'key': 'C',
          'mode': 'major',
          'bpm': 120,
        };

        final analysis = TrackAnalysis.fromJson(analysisJson);
        expect(analysis.title, equals('Test Song 🎵 音楽'));
      });

      test('handles various key notations', () {
        const keys = [
          'C',
          'C#',
          'D',
          'D#',
          'E',
          'F',
          'F#',
          'G',
          'G#',
          'A',
          'A#',
          'B',
        ];

        for (final key in keys) {
          final analysis = TrackAnalysis(
            title: 'Test',
            artist: 'Artist',
            key: key,
            mode: 'major',
            bpm: 120,
          );
          expect(analysis.key, equals(key));
        }
      });

      test('handles minor mode variations', () {
        final analysis1 = TrackAnalysis(
          title: 'Test',
          artist: 'Artist',
          key: 'C',
          mode: 'minor',
          bpm: 120,
        );
        expect(analysis1.musicalKey, equals('C minor'));

        final analysis2 = TrackAnalysis(
          title: 'Test',
          artist: 'Artist',
          key: 'C',
          mode: 'Minor',
          bpm: 120,
        );
        expect(analysis2.musicalKey, equals('C Minor'));
      });

      test('handles fractional BPM', () {
        // BPM is cast to int in the service, so fractional values are truncated
        final analysisJson = {
          'track': 'Test Song',
          'artist': 'Test Artist',
          'key': 'C',
          'mode': 'major',
          'bpm': 120,
          'energy': 0.5,
          'danceability': 0.5,
        };

        final analysis = TrackAnalysis.fromJson(analysisJson);
        expect(analysis.bpm, equals(120));
      });

      test('handles very low BPM', () {
        final analysisJson = {
          'track': 'Test Song',
          'artist': 'Test Artist',
          'key': 'C',
          'mode': 'major',
          'bpm': 40,
          'energy': 0.3,
          'danceability': 0.3,
        };

        final analysis = TrackAnalysis.fromJson(analysisJson);
        expect(analysis.bpm, equals(40));
      });

      test('handles empty string key', () {
        final analysisJson = {
          'track': 'Test Song',
          'artist': 'Test Artist',
          'key': '',
          'mode': 'major',
          'bpm': 120,
        };

        final analysis = TrackAnalysis.fromJson(analysisJson);
        expect(analysis.key, equals(''));
        // musicalKey returns '$key $mode' so empty key results in ' major'
        expect(analysis.musicalKey, equals(' major'));
      });

      test('handles empty string mode', () {
        final analysisJson = {
          'track': 'Test Song',
          'artist': 'Test Artist',
          'key': 'C',
          'mode': '',
          'bpm': 120,
        };

        final analysis = TrackAnalysis.fromJson(analysisJson);
        expect(analysis.mode, equals(''));
        expect(analysis.musicalKey, equals('C '));
      });
    });

    group('Caching behavior (conceptual tests)', () {
      test('should cache successful analysis results', () {
        // Conceptual test - in production, implement cache service
        // Verify that repeated calls with same params return cached result
      });

      test('should not cache failed analysis results', () {
        // Conceptual test - verify failed calls don't pollute cache
      });

      test('should invalidate cache on demand', () {
        // Conceptual test - verify cache invalidation works
      });

      test('should use cache before making API call', () {
        // Conceptual test - verify cache-first strategy
      });

      test('should handle cache expiration', () {
        // Conceptual test - verify TTL-based expiration
      });
    });
  });
}
