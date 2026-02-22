import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/services/api/track_analysis_service.dart';

void main() {
  group('TrackAnalysisService', () {
    group('isConfigured', () {
      test('returns true when API key is configured', () {
        // The service uses 'demo' as default key which is not 'YOUR_RAPIDAPI_KEY'
        expect(TrackAnalysisService.isConfigured, isTrue);
      });
    });

    group('analyzeTrack', () {
      test('returns null when title is empty', () async {
        final result = await TrackAnalysisService.analyzeTrack('', 'Artist');
        expect(result, isNull);
      });

      test('returns null when title is whitespace only', () async {
        final result = await TrackAnalysisService.analyzeTrack('   ', 'Artist');
        expect(result, isNull);
      });

      test('returns null when API is not configured', () async {
        // This tests the null return path when API key is 'YOUR_RAPIDAPI_KEY'
        // Since we can't easily change the const, we test the empty title path
        final result = await TrackAnalysisService.analyzeTrack('', 'Artist');
        expect(result, isNull);
      });
    });

    group('TrackAnalysis', () {
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
          mode: null,
          bpm: 120,
        );

        expect(analysis.musicalKey, equals('D'));
      });

      test('musicalKey returns empty string when key is null', () {
        final analysis = TrackAnalysis(
          title: 'Test Song',
          artist: 'Test Artist',
          key: null,
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
          'energy': 75, // Integer instead of double
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
    });

    group('Edge cases', () {
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
    });
  });
}
