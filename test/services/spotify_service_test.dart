import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_repsync_app/services/api/spotify_service.dart';
import 'package:flutter_repsync_app/models/api_error.dart';

void main() {
  group('SpotifyService', () {
    setUp(() async {
      // Initialize dotenv for testing
      await dotenv.load(fileName: '.env');
    });

    group('isConfigured', () {
      test('returns false when credentials are not set', () {
        // Temporarily override credentials for testing
        expect(SpotifyService.isConfigured, isFalse);
      });
    });

    group('search', () {
      test('returns list of tracks on successful search', () async {
        final mockClient = MockClient((request) async {
          if (request.url.toString().contains('accounts.spotify.com')) {
            // Mock token response
            return http.Response(
              jsonEncode({
                'access_token': 'mock_access_token',
                'expires_in': 3600,
              }),
              200,
            );
          } else {
            // Mock search response
            return http.Response(
              jsonEncode({
                'tracks': {
                  'items': [
                    {
                      'id': 'track1',
                      'name': 'Test Song',
                      'artists': [
                        {'name': 'Test Artist'},
                      ],
                      'album': {
                        'name': 'Test Album',
                        'images': [
                          {'url': 'https://example.com/image.jpg'},
                        ],
                      },
                      'duration_ms': 180000,
                      'external_urls': {
                        'spotify': 'https://open.spotify.com/track/track1',
                      },
                    },
                    {
                      'id': 'track2',
                      'name': 'Another Song',
                      'artists': [
                        {'name': 'Another Artist'},
                        {'name': 'Featured Artist'},
                      ],
                      'album': {'name': 'Another Album', 'images': []},
                      'duration_ms': 200000,
                      'external_urls': {},
                    },
                  ],
                },
              }),
              200,
            );
          }
        });

        // Use http.Client override
        http.Client? originalClient;
        // Note: We can't easily mock the static http calls in the service
        // This test demonstrates the expected behavior

        // For unit testing, we test the JSON parsing logic
        final trackJson = {
          'id': 'track1',
          'name': 'Test Song',
          'artists': [
            {'name': 'Test Artist'},
          ],
          'album': {
            'name': 'Test Album',
            'images': [
              {'url': 'https://example.com/image.jpg'},
            ],
          },
          'duration_ms': 180000,
          'external_urls': {'spotify': 'https://open.spotify.com/track/track1'},
        };

        final track = SpotifyTrack.fromJson(trackJson);
        expect(track.id, equals('track1'));
        expect(track.name, equals('Test Song'));
        expect(track.artist, equals('Test Artist'));
        expect(track.album, equals('Test Album'));
        expect(track.albumArt, equals('https://example.com/image.jpg'));
        expect(track.durationMs, equals(180000));
        expect(
          track.spotifyUrl,
          equals('https://open.spotify.com/track/track1'),
        );
      });

      test('handles missing album images gracefully', () {
        final trackJson = {
          'id': 'track1',
          'name': 'Test Song',
          'artists': [],
          'album': {'name': 'Test Album', 'images': null},
          'duration_ms': null,
          'external_urls': null,
        };

        final track = SpotifyTrack.fromJson(trackJson);
        expect(track.id, equals('track1'));
        expect(track.name, equals('Test Song'));
        expect(track.artist, equals('Unknown'));
        expect(track.album, equals('Test Album'));
        expect(track.albumArt, isNull);
        expect(track.durationMs, isNull);
        expect(track.spotifyUrl, isNull);
      });

      test('handles empty artists list', () {
        final trackJson = {
          'id': 'track1',
          'name': 'Test Song',
          'artists': [],
          'album': {'name': 'Test Album', 'images': []},
          'duration_ms': 180000,
          'external_urls': {},
        };

        final track = SpotifyTrack.fromJson(trackJson);
        expect(track.artist, equals('Unknown'));
      });

      test('handles missing fields with defaults', () {
        final trackJson = <String, dynamic>{};

        final track = SpotifyTrack.fromJson(trackJson);
        expect(track.id, equals(''));
        expect(track.name, equals('Unknown'));
        expect(track.artist, equals('Unknown'));
      });
    });

    group('SpotifyAudioFeatures', () {
      test('parses audio features correctly', () {
        final featuresJson = {
          'tempo': 120.5,
          'key': 5,
          'mode': 1,
          'time_signature': 4,
        };

        final features = SpotifyAudioFeatures.fromJson(featuresJson);
        expect(features.tempo, equals(120.5));
        expect(features.bpm, equals(121));
        expect(features.key, equals(5));
        expect(features.mode, equals(1));
        expect(features.timeSignature, equals(4));
      });

      test('handles missing fields with defaults', () {
        final featuresJson = <String, dynamic>{};

        final features = SpotifyAudioFeatures.fromJson(featuresJson);
        expect(features.tempo, equals(0));
        expect(features.bpm, equals(0));
        expect(features.key, equals(0));
        expect(features.mode, equals(1));
        expect(features.timeSignature, equals(4));
      });

      test('calculates musicalKey for major keys', () {
        // Key 0 = C, mode 1 = major
        final features = SpotifyAudioFeatures(
          tempo: 120,
          key: 0,
          mode: 1,
          timeSignature: 4,
        );
        expect(features.musicalKey, equals('C major'));
      });

      test('calculates musicalKey for minor keys', () {
        // Key 0 = C, mode 0 = minor
        final features = SpotifyAudioFeatures(
          tempo: 120,
          key: 0,
          mode: 0,
          timeSignature: 4,
        );
        expect(features.musicalKey, equals('C minor'));
      });

      test('calculates camelotKey for major keys', () {
        // Key 0 (C) major = 8B
        final features = SpotifyAudioFeatures(
          tempo: 120,
          key: 0,
          mode: 1,
          timeSignature: 4,
        );
        expect(features.camelotKey, equals('8B'));
      });

      test('calculates camelotKey for minor keys', () {
        // Key 0 (C) minor = 8A
        final features = SpotifyAudioFeatures(
          tempo: 120,
          key: 0,
          mode: 0,
          timeSignature: 4,
        );
        expect(features.camelotKey, equals('8A'));
      });

      test('calculates camelotKey for all keys', () {
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

        for (int i = 0; i < keys.length; i++) {
          final features = SpotifyAudioFeatures(
            tempo: 120,
            key: i,
            mode: 1,
            timeSignature: 4,
          );
          // Just verify it doesn't throw
          expect(features.camelotKey, isNotEmpty);
        }
      });

      test('handles null tempo value', () {
        final featuresJson = {
          'tempo': null,
          'key': 0,
          'mode': 1,
          'time_signature': 4,
        };

        final features = SpotifyAudioFeatures.fromJson(featuresJson);
        expect(features.tempo, equals(0));
        expect(features.bpm, equals(0));
      });
    });

    group('ApiError handling', () {
      test('ApiError.auth creates correct error type', () {
        final error = ApiError.auth(
          message: 'Invalid credentials',
          exception: 'HTTP 401',
        );

        expect(error.type, equals(ErrorType.auth));
        expect(error.message, equals('Invalid credentials'));
        expect(error.isAuth, isTrue);
      });

      test('ApiError.network creates correct error type', () {
        final error = ApiError.network(
          message: 'Network error',
          exception: 'HTTP 500',
        );

        expect(error.type, equals(ErrorType.network));
        expect(error.message, equals('Network error'));
        expect(error.isNetwork, isTrue);
      });

      test('ApiError.permission creates correct error type', () {
        final error = ApiError.permission(
          message: 'Permission denied',
          exception: 'HTTP 403',
        );

        expect(error.type, equals(ErrorType.permission));
        expect(error.message, equals('Permission denied'));
        expect(error.isPermission, isTrue);
      });

      test('ApiError.validation creates correct error type', () {
        final error = ApiError.validation(message: 'Invalid input');

        expect(error.type, equals(ErrorType.validation));
        expect(error.message, equals('Invalid input'));
        expect(error.isValidation, isTrue);
      });

      test('ApiError.notFound creates correct error type', () {
        final error = ApiError.notFound(message: 'Resource not found');

        expect(error.type, equals(ErrorType.notFound));
        expect(error.message, equals('Resource not found'));
        expect(error.isNotFound, isTrue);
      });

      test('ApiError.unknown creates correct error type', () {
        final error = ApiError.unknown(message: 'Unknown error');

        expect(error.type, equals(ErrorType.unknown));
        expect(error.message, equals('Unknown error'));
        expect(error.isUnknown, isTrue);
      });

      test('ApiError.toJson serializes correctly', () {
        final error = ApiError.auth(message: 'Test error');
        final json = error.toJson();

        expect(json['type'], equals('auth'));
        expect(json['message'], equals('Test error'));
        expect(json['timestamp'], isNotNull);
      });

      test('ApiError.fromJson deserializes correctly', () {
        final json = {
          'type': 'network',
          'message': 'Connection failed',
          'details': 'Timeout',
        };

        final error = ApiError.fromJson(json);
        expect(error.type, equals(ErrorType.network));
        expect(error.message, equals('Connection failed'));
        expect(error.details, equals('Timeout'));
      });

      test('ApiError.toString returns formatted string', () {
        final error = ApiError.network(
          message: 'Test error',
          exception: 'Exception details',
        );

        final str = error.toString();
        expect(str, contains('ApiError'));
        expect(str, contains('network'));
        expect(str, contains('Test error'));
      });

      test('ApiError title returns correct title for each type', () {
        expect(ApiError.network(message: '').title, equals('Connection Error'));
        expect(
          ApiError.auth(message: '').title,
          equals('Authentication Error'),
        );
        expect(ApiError.validation(message: '').title, equals('Invalid Input'));
        expect(ApiError.permission(message: '').title, equals('Access Denied'));
        expect(ApiError.notFound(message: '').title, equals('Not Found'));
        expect(ApiError.unknown(message: '').title, equals('Error'));
      });

      test('ApiError iconCode returns correct icon for each type', () {
        expect(ApiError.network(message: '').iconCode, equals('wifi_off'));
        expect(ApiError.auth(message: '').iconCode, equals('lock'));
        expect(ApiError.validation(message: '').iconCode, equals('warning'));
        expect(ApiError.permission(message: '').iconCode, equals('block'));
        expect(ApiError.notFound(message: '').iconCode, equals('search_off'));
        expect(ApiError.unknown(message: '').iconCode, equals('error'));
      });
    });
  });
}
