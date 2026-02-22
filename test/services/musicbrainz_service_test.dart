import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/services/musicbrainz_service.dart';
import 'package:flutter_repsync_app/models/api_error.dart';

void main() {
  group('MusicBrainzService', () {
    group('MusicBrainzRecording', () {
      test('parses recording with all fields correctly', () {
        final recordingJson = {
          'title': 'Test Song',
          'artist-credit': [
            {
              'artist': {'name': 'Test Artist'},
            },
          ],
          'releases': [
            {'title': 'Test Album'},
          ],
          'length': 180000, // in milliseconds
        };

        final recording = MusicBrainzRecording.fromJson(recordingJson);
        expect(recording.title, equals('Test Song'));
        expect(recording.artist, equals('Test Artist'));
        expect(recording.release, equals('Test Album'));
        expect(recording.durationMs, equals(180000));
        expect(recording.bpm, isNotNull);
      });

      test('calculates BPM from duration correctly', () {
        // 60000ms / 500ms = 120 BPM
        final recordingJson = {
          'title': 'Test Song',
          'artist-credit': [
            {
              'artist': {'name': 'Test Artist'},
            },
          ],
          'releases': [],
          'length': 500, // Very short for testing
        };

        final recording = MusicBrainzRecording.fromJson(recordingJson);
        // BPM should be calculated as 60000 / duration_ms
        expect(recording.bpm, equals(120));
      });

      test('returns null BPM for duration outside valid range', () {
        // Duration too short (would result in BPM > 300)
        final recordingJson1 = {
          'title': 'Test Song',
          'artist-credit': [
            {
              'artist': {'name': 'Test Artist'},
            },
          ],
          'releases': [],
          'length': 100, // 60000/100 = 600 BPM (too high)
        };

        final recording1 = MusicBrainzRecording.fromJson(recordingJson1);
        expect(recording1.bpm, isNull);

        // Duration too long (would result in BPM < 40)
        final recordingJson2 = {
          'title': 'Test Song',
          'artist-credit': [
            {
              'artist': {'name': 'Test Artist'},
            },
          ],
          'releases': [],
          'length': 2000, // 60000/2000 = 30 BPM (too low)
        };

        final recording2 = MusicBrainzRecording.fromJson(recordingJson2);
        expect(recording2.bpm, isNull);
      });

      test('handles missing artist-credit gracefully', () {
        final recordingJson = {
          'title': 'Test Song',
          'artist-credit': null,
          'releases': [],
          'length': 180000,
        };

        final recording = MusicBrainzRecording.fromJson(recordingJson);
        expect(recording.artist, isNull);
      });

      test('handles empty artist-credit list', () {
        final recordingJson = {
          'title': 'Test Song',
          'artist-credit': [],
          'releases': [],
          'length': 180000,
        };

        final recording = MusicBrainzRecording.fromJson(recordingJson);
        expect(recording.artist, isNull);
      });

      test('handles missing releases gracefully', () {
        final recordingJson = {
          'title': 'Test Song',
          'artist-credit': [
            {
              'artist': {'name': 'Test Artist'},
            },
          ],
          'releases': null,
          'length': 180000,
        };

        final recording = MusicBrainzRecording.fromJson(recordingJson);
        expect(recording.release, isNull);
      });

      test('handles empty releases list', () {
        final recordingJson = {
          'title': 'Test Song',
          'artist-credit': [
            {
              'artist': {'name': 'Test Artist'},
            },
          ],
          'releases': [],
          'length': 180000,
        };

        final recording = MusicBrainzRecording.fromJson(recordingJson);
        expect(recording.release, isNull);
      });

      test('handles missing length field', () {
        final recordingJson = {
          'title': 'Test Song',
          'artist-credit': [
            {
              'artist': {'name': 'Test Artist'},
            },
          ],
          'releases': [],
        };

        final recording = MusicBrainzRecording.fromJson(recordingJson);
        expect(recording.durationMs, isNull);
        expect(recording.bpm, isNull);
      });

      test('handles missing title field', () {
        final recordingJson = {
          'artist-credit': [
            {
              'artist': {'name': 'Test Artist'},
            },
          ],
          'releases': [],
        };

        final recording = MusicBrainzRecording.fromJson(recordingJson);
        expect(recording.title, isNull);
      });

      test('displayInfo includes release and BPM', () {
        final recording = MusicBrainzRecording(
          title: 'Test Song',
          artist: 'Test Artist',
          release: 'Test Album',
          durationMs: 180000,
          bpm: 120,
        );

        expect(recording.displayInfo, equals('(Test Album, 120 BPM)'));
      });

      test('displayInfo includes only BPM when no release', () {
        final recording = MusicBrainzRecording(
          title: 'Test Song',
          artist: 'Test Artist',
          release: null,
          durationMs: 180000,
          bpm: 120,
        );

        expect(recording.displayInfo, equals('(120 BPM)'));
      });

      test('displayInfo includes only release when no BPM', () {
        final recording = MusicBrainzRecording(
          title: 'Test Song',
          artist: 'Test Artist',
          release: 'Test Album',
          durationMs: 180000,
          bpm: null,
        );

        expect(recording.displayInfo, equals('(Test Album)'));
      });

      test('displayInfo returns empty string when no release and no BPM', () {
        final recording = MusicBrainzRecording(
          title: 'Test Song',
          artist: 'Test Artist',
          release: null,
          durationMs: null,
          bpm: null,
        );

        expect(recording.displayInfo, equals(''));
      });

      test('handles artist-credit with non-map entries', () {
        final recordingJson = {
          'title': 'Test Song',
          'artist-credit': ['invalid'],
          'releases': [],
          'length': 180000,
        };

        final recording = MusicBrainzRecording.fromJson(recordingJson);
        expect(recording.artist, isNull);
      });

      test('handles artist-credit artist as null', () {
        final recordingJson = {
          'title': 'Test Song',
          'artist-credit': [
            {'artist': null},
          ],
          'releases': [],
          'length': 180000,
        };

        final recording = MusicBrainzRecording.fromJson(recordingJson);
        expect(recording.artist, isNull);
      });

      test('handles releases with non-map entries', () {
        final recordingJson = {
          'title': 'Test Song',
          'artist-credit': [
            {
              'artist': {'name': 'Test Artist'},
            },
          ],
          'releases': ['invalid'],
          'length': 180000,
        };

        final recording = MusicBrainzRecording.fromJson(recordingJson);
        expect(recording.release, isNull);
      });
    });

    group('searchRecording validation', () {
      test('throws ApiError.validation for empty query', () async {
        expect(
          () => MusicBrainzService.searchRecording(''),
          throwsA(
            isA<ApiError>().having((e) => e.type, 'type', ErrorType.validation),
          ),
        );
      });

      test('throws ApiError.validation for whitespace-only query', () async {
        expect(
          () => MusicBrainzService.searchRecording('   '),
          throwsA(
            isA<ApiError>().having((e) => e.type, 'type', ErrorType.validation),
          ),
        );
      });
    });

    group('ApiError handling', () {
      test('ApiError.network handles 500 errors', () {
        final error = ApiError.network(
          message: 'Server unavailable',
          exception: 'HTTP 500: Internal Server Error',
        );

        expect(error.type, equals(ErrorType.network));
        expect(error.isNetwork, isTrue);
      });

      test('ApiError.fromException handles socket exceptions', () {
        final exception = Exception('SocketException: Connection refused');
        final error = ApiError.fromException(exception);

        expect(error.type, equals(ErrorType.network));
        expect(error.isNetwork, isTrue);
      });

      test('ApiError.fromException handles timeout exceptions', () {
        final exception = Exception('TimeoutException: Connection timed out');
        final error = ApiError.fromException(exception);

        expect(error.type, equals(ErrorType.network));
        expect(error.isNetwork, isTrue);
      });

      test('ApiError.fromException handles HTTP exceptions', () {
        final exception = Exception('HttpException: Connection reset');
        final error = ApiError.fromException(exception);

        expect(error.type, equals(ErrorType.network));
        expect(error.isNetwork, isTrue);
      });

      test('ApiError.fromException handles auth exceptions', () {
        final exception = Exception('AuthException: Invalid token');
        final error = ApiError.fromException(exception);

        expect(error.type, equals(ErrorType.auth));
        expect(error.isAuth, isTrue);
      });

      test('ApiError.fromException handles unauthorized exceptions', () {
        final exception = Exception('Unauthorized: Access denied');
        final error = ApiError.fromException(exception);

        expect(error.type, equals(ErrorType.auth));
        expect(error.isAuth, isTrue);
      });

      test('ApiError.fromException handles validation exceptions', () {
        final exception = Exception('InvalidFormatException: Invalid input');
        final error = ApiError.fromException(exception);

        expect(error.type, equals(ErrorType.validation));
        expect(error.isValidation, isTrue);
      });

      test('ApiError.fromException handles not found exceptions', () {
        final exception = Exception('NotFoundException: Resource not found');
        final error = ApiError.fromException(exception);

        expect(error.type, equals(ErrorType.notFound));
        expect(error.isNotFound, isTrue);
      });

      test('ApiError.fromException handles 404 in error string', () {
        final exception = Exception('HTTP 404: Not Found');
        final error = ApiError.fromException(exception);

        expect(error.type, equals(ErrorType.notFound));
        expect(error.isNotFound, isTrue);
      });

      test(
        'ApiError.fromException returns unknown for unhandled exceptions',
        () {
          final exception = Exception('Some random exception');
          final error = ApiError.fromException(exception);

          expect(error.type, equals(ErrorType.unknown));
          expect(error.isUnknown, isTrue);
        },
      );

      test(
        'ApiError.fromException returns same ApiError if already ApiError',
        () {
          final originalError = ApiError.network(message: 'Network error');
          final error = ApiError.fromException(originalError);

          expect(error, equals(originalError));
          expect(error.type, equals(ErrorType.network));
        },
      );
    });
  });
}
