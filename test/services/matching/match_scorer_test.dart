/// Unit tests for match scoring.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_repsync_app/models/song.dart';
import 'package:flutter_repsync_app/services/matching/match_scorer.dart';

void main() {
  Song _createSong({
    required String title,
    required String artist,
    int? durationMs,
    String? album,
  }) {
    return Song(
      id: const Uuid().v4(),
      title: title,
      artist: artist,
      durationMs: durationMs,
      album: album,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  group('MatchScorer', () {
    group('calculate', () {
      test('exact match returns 100%', () {
        final existingSong = _createSong(
          title: 'Bohemian Rhapsody',
          artist: 'Queen',
        );

        final score = MatchScorer.calculate(
          inputTitle: 'Bohemian Rhapsody',
          inputArtist: 'Queen',
          existingSong: existingSong,
        );

        expect(score.total, greaterThan(99));
        expect(score.grade, equals(MatchGrade.exact));
      });

      test('typo in title returns high match', () {
        final existingSong = _createSong(
          title: 'Bohemian Rhapsody',
          artist: 'Queen',
        );

        final score = MatchScorer.calculate(
          inputTitle: 'Bohemian Rapsody',
          inputArtist: 'Queen',
          existingSong: existingSong,
        );

        // With weight redistribution, typo still scores very high
        expect(score.total, greaterThan(85));
        expect(
          score.grade,
          anyOf(equals(MatchGrade.high), equals(MatchGrade.exact)),
        );
      });

      test('missing "The" in artist returns high match', () {
        final existingSong = _createSong(
          title: 'Hey Jude',
          artist: 'The Beatles',
        );

        final score = MatchScorer.calculate(
          inputTitle: 'Hey Jude',
          inputArtist: 'Beatles',
          existingSong: existingSong,
        );

        expect(score.total, greaterThan(85));
        expect(
          score.grade,
          anyOf(equals(MatchGrade.high), equals(MatchGrade.exact)),
        );
      });

      test('different song returns low match', () {
        final existingSong = _createSong(
          title: 'Bohemian Rhapsody',
          artist: 'Queen',
        );

        final score = MatchScorer.calculate(
          inputTitle: 'Hotel California',
          inputArtist: 'Eagles',
          existingSong: existingSong,
        );

        expect(score.total, lessThan(50));
        expect(score.grade, equals(MatchGrade.none));
      });

      test('same title different artist is medium match', () {
        final existingSong = _createSong(
          title: 'Yesterday',
          artist: 'The Beatles',
        );

        final score = MatchScorer.calculate(
          inputTitle: 'Yesterday',
          inputArtist: 'Ray Charles',
          existingSong: existingSong,
        );

        // Title matches but artist doesn't
        expect(score.titleSimilarity, greaterThan(90));
        expect(score.artistSimilarity, lessThan(50));
      });

      test('duration similarity boosts score', () {
        final existingSong = _createSong(
          title: 'Song',
          artist: 'Artist',
          durationMs: 300000, // 5 minutes
        );

        final scoreWithMatchingDuration = MatchScorer.calculate(
          inputTitle: 'Song',
          inputArtist: 'Artist',
          inputDuration: 300000,
          existingSong: existingSong,
        );

        final scoreWithDifferentDuration = MatchScorer.calculate(
          inputTitle: 'Song',
          inputArtist: 'Artist',
          inputDuration: 180000, // 3 minutes
          existingSong: existingSong,
        );

        expect(
          scoreWithMatchingDuration.durationSimilarity,
          greaterThan(scoreWithDifferentDuration.durationSimilarity),
        );
      });

      test('album similarity boosts score', () {
        final existingSong = _createSong(
          title: 'Song',
          artist: 'Artist',
          album: 'Greatest Hits',
        );

        final scoreWithMatchingAlbum = MatchScorer.calculate(
          inputTitle: 'Song',
          inputArtist: 'Artist',
          inputAlbum: 'Greatest Hits',
          existingSong: existingSong,
        );

        final scoreWithDifferentAlbum = MatchScorer.calculate(
          inputTitle: 'Song',
          inputArtist: 'Artist',
          inputAlbum: 'Live Album',
          existingSong: existingSong,
        );

        expect(
          scoreWithMatchingAlbum.albumSimilarity,
          greaterThan(scoreWithDifferentAlbum.albumSimilarity),
        );
      });
    });

    group('applySpecialRules', () {
      test('empty artist input weights title higher', () {
        final existingSong = _createSong(
          title: 'Bohemian Rhapsody',
          artist: 'Queen',
        );

        final baseScore = MatchScorer.calculate(
          inputTitle: 'Bohemian Rapsody',
          inputArtist: '',
          existingSong: existingSong,
        );

        final adjustedScore = MatchScorer.applySpecialRules(baseScore, '');

        // With empty artist, title should be weighted more
        expect(adjustedScore.total, greaterThanOrEqualTo(baseScore.total));
      });

      test('live version without live in query reduces score', () {
        final liveSong = _createSong(title: 'Song (Live)', artist: 'Artist');

        final score = MatchScorer.calculate(
          inputTitle: 'Song',
          inputArtist: 'Artist',
          existingSong: liveSong,
        );

        final adjustedScore = MatchScorer.applySpecialRules(score, 'Artist');

        // Live version should have reduced score if user didn't search for live
        expect(adjustedScore.total, lessThan(score.total));
      });
    });
  });

  group('MatchScore', () {
    test('grade is exact for >= 95%', () {
      final score = MatchScore(
        total: 96,
        titleSimilarity: 96,
        artistSimilarity: 96,
        durationSimilarity: 0,
        albumSimilarity: 0,
        matchedSong: _createSong(title: 'Test', artist: 'Test'),
      );

      expect(score.grade, equals(MatchGrade.exact));
      expect(score.isStrongMatch, isTrue);
      expect(score.shouldSuggest, isTrue);
    });

    test('grade is high for 85-94%', () {
      final score = MatchScore(
        total: 90,
        titleSimilarity: 90,
        artistSimilarity: 90,
        durationSimilarity: 0,
        albumSimilarity: 0,
        matchedSong: _createSong(title: 'Test', artist: 'Test'),
      );

      expect(score.grade, equals(MatchGrade.high));
      expect(score.isStrongMatch, isTrue);
      expect(score.shouldSuggest, isTrue);
    });

    test('grade is medium for 70-84%', () {
      final score = MatchScore(
        total: 75,
        titleSimilarity: 75,
        artistSimilarity: 75,
        durationSimilarity: 0,
        albumSimilarity: 0,
        matchedSong: _createSong(title: 'Test', artist: 'Test'),
      );

      expect(score.grade, equals(MatchGrade.medium));
      expect(score.isStrongMatch, isFalse);
      expect(score.shouldSuggest, isTrue);
    });

    test('grade is low for 50-69%', () {
      final score = MatchScore(
        total: 60,
        titleSimilarity: 60,
        artistSimilarity: 60,
        durationSimilarity: 0,
        albumSimilarity: 0,
        matchedSong: _createSong(title: 'Test', artist: 'Test'),
      );

      expect(score.grade, equals(MatchGrade.low));
      expect(score.isStrongMatch, isFalse);
      expect(score.shouldSuggest, isFalse);
    });

    test('grade is none for < 50%', () {
      final score = MatchScore(
        total: 40,
        titleSimilarity: 40,
        artistSimilarity: 40,
        durationSimilarity: 0,
        albumSimilarity: 0,
        matchedSong: _createSong(title: 'Test', artist: 'Test'),
      );

      expect(score.grade, equals(MatchGrade.none));
      expect(score.isStrongMatch, isFalse);
      expect(score.shouldSuggest, isFalse);
    });
  });

  group('MatchThresholds', () {
    test('REQUIRE_REVIEW is 70', () {
      expect(MatchThresholds.REQUIRE_REVIEW, equals(70.0));
    });

    test('SUGGEST_MATCH is 85', () {
      expect(MatchThresholds.SUGGEST_MATCH, equals(85.0));
    });

    test('AUTO_SELECT is 98', () {
      expect(MatchThresholds.AUTO_SELECT, equals(98.0));
    });

    test('EXACT_MATCH is 99.5', () {
      expect(MatchThresholds.EXACT_MATCH, equals(99.5));
    });
  });
}
