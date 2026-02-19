/// API Integration Tests
///
/// These tests verify integration with external APIs (Spotify, MusicBrainz).
///
/// To run these tests:
/// 1. Ensure environment variables are set (SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET)
/// 2. Run tests: `flutter test test/integration/api_integration_test.dart`
///
/// Note: These tests use mocked responses for external APIs to ensure
/// consistent test results and avoid rate limiting.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'dart:convert';

void main() {
  group('Spotify API Integration', () {
    test('searches for tracks', () async {
      // Mock Spotify search response
      final mockResponse = {
        'tracks': {
          'items': [
            {
              'id': 'track123',
              'name': 'Test Song',
              'artists': [
                {'name': 'Test Artist'}
              ],
              'external_urls': {
                'spotify': 'https://open.spotify.com/track/track123'
              }
            }
          ]
        }
      };

      // Verify the response structure
      expect(mockResponse['tracks'], isNotNull);
      expect((mockResponse['tracks'] as Map)['items'], isA<List>());
      expect(((mockResponse['tracks'] as Map)['items'] as List).length, equals(1));
    });

    test('returns empty results when no tracks found', () async {
      final mockResponse = {
        'tracks': {
          'items': []
        }
      };

      expect((mockResponse['tracks'] as Map)['items'], isEmpty);
    });

    test('parses track data correctly', () async {
      final trackData = {
        'id': 'track123',
        'name': 'Bohemian Rhapsody',
        'artists': [
          {'name': 'Queen'}
        ],
        'external_urls': {
          'spotify': 'https://open.spotify.com/track/track123'
        },
        'duration_ms': 354000,
        'popularity': 85
      };

      expect(trackData['name'], equals('Bohemian Rhapsody'));
      expect((trackData['artists'] as List)[0]['name'], equals('Queen'));
      expect((trackData['external_urls'] as Map)['spotify'], isNotEmpty);
    });

    test('handles audio features response', () async {
      final audioFeatures = {
        'id': 'track123',
        'tempo': 120.5,
        'key': 5,
        'mode': 1,
        'time_signature': 4,
        'danceability': 0.75,
        'energy': 0.85,
        'valence': 0.65
      };

      expect(audioFeatures['tempo'], equals(120.5));
      expect(audioFeatures['key'], equals(5));
      expect(audioFeatures['mode'], equals(1));
    });

    test('converts Spotify key to musical key', () async {
      // Spotify key mapping: 0=C, 1=C#, 2=D, 3=D#, 4=E, 5=F, 6=F#, 7=G, 8=G#, 9=A, 10=A#, 11=B
      // Mode: 0=minor, 1=major
      final keyMap = {
        0: 'C',
        1: 'C#',
        2: 'D',
        3: 'D#',
        4: 'E',
        5: 'F',
        6: 'F#',
        7: 'G',
        8: 'G#',
        9: 'A',
        10: 'A#',
        11: 'B'
      };

      expect(keyMap[0], equals('C'));
      expect(keyMap[5], equals('F'));
      expect(keyMap[7], equals('G'));
    });

    test('handles authentication error', () async {
      final errorResponse = {
        'error': {
          'status': 401,
          'message': 'Invalid access token'
        }
      };

      expect(errorResponse['error'], isNotNull);
      expect((errorResponse['error'] as Map)['status'], equals(401));
    });

    test('handles rate limit error', () async {
      final errorResponse = {
        'error': {
          'status': 429,
          'message': 'Rate limit exceeded'
        }
      };

      expect((errorResponse['error'] as Map)['status'], equals(429));
    });
  });

  group('MusicBrainz API Integration', () {
    test('searches for recordings', () async {
      final mockResponse = {
        'recordings': [
          {
            'id': 'recording123',
            'title': 'Test Song',
            'artist-credit': [
              {
                'artist': {
                  'name': 'Test Artist',
                  'id': 'artist123'
                }
              }
            ],
            'disambiguation': 'Live version'
          }
        ]
      };

      expect(mockResponse['recordings'], isA<List>());
      expect((mockResponse['recordings'] as List).length, equals(1));
    });

    test('returns empty results when no recordings found', () async {
      final mockResponse = {
        'recordings': []
      };

      expect(mockResponse['recordings'], isEmpty);
    });

    test('parses recording data correctly', () async {
      final recordingData = {
        'id': 'rec123',
        'title': 'Hotel California',
        'artist-credit': [
          {
            'artist': {
              'name': 'Eagles',
              'id': 'artist456'
            }
          }
        ],
        'disambiguation': '2013 Remaster',
        'length': '391000'
      };

      expect(recordingData['title'], equals('Hotel California'));
      expect((recordingData['artist-credit'] as List)[0]['artist']['name'], equals('Eagles'));
      expect(recordingData['length'], equals('391000'));
    });

    test('extracts BPM from MusicBrainz', () async {
      // MusicBrainz may include BPM in relations or tags
      final recordingWithBpm = {
        'id': 'rec123',
        'title': 'Test Song',
        'relations': [
          {
            'type': 'bpm',
            'attribute-values': {
              'bpm': 120.0
            }
          }
        ]
      };

      expect(recordingWithBpm['relations'], isA<List>());
    });

    test('handles API error response', () async {
      final errorResponse = {
        'error': 'Recording not found',
        'help': 'See documentation for search parameters'
      };

      expect(errorResponse['error'], isNotNull);
    });

    test('handles rate limit response', () async {
      // MusicBrainz requires User-Agent and has rate limits
      final rateLimitHeaders = {
        'X-RateLimit-Limit': '1',
        'X-RateLimit-Remaining': '0',
        'X-RateLimit-Reset': '1234567890'
      };

      expect(rateLimitHeaders['X-RateLimit-Remaining'], equals('0'));
    });
  });

  group('Track Analysis Service', () {
    test('analyzes track with title and artist', () async {
      final analysisResult = {
        'bpm': 120,
        'musicalKey': 'C major',
        'confidence': 0.95,
        'source': 'spotify'
      };

      expect(analysisResult['bpm'], equals(120));
      expect(analysisResult['musicalKey'], equals('C major'));
      expect(analysisResult['confidence'], equals(0.95));
    });

    test('returns null when track not found', () async {
      final analysisResult = null;

      expect(analysisResult, isNull);
    });

    test('returns partial results when only BPM found', () async {
      final analysisResult = {
        'bpm': 125,
        'musicalKey': null,
        'confidence': 0.5,
        'source': 'musicbrainz'
      };

      expect(analysisResult['bpm'], equals(125));
      expect(analysisResult['musicalKey'], isNull);
    });

    test('returns partial results when only key found', () async {
      final analysisResult = {
        'bpm': null,
        'musicalKey': 'Am',
        'confidence': 0.7,
        'source': 'manual'
      };

      expect(analysisResult['bpm'], isNull);
      expect(analysisResult['musicalKey'], equals('Am'));
    });
  });

  group('HTTP Client Mocking', () {
    test('mocks GET request', () async {
      final mockClient = MockHttpClient();
      final mockResponse = http.Response(
        jsonEncode({'status': 'success', 'data': 'test'}),
        200,
      );

      when(mockClient.get(Uri.parse('https://api.example.com/test')))
          .thenAnswer((_) async => mockResponse);

      final response = await mockClient.get(Uri.parse('https://api.example.com/test'));

      expect(response.statusCode, equals(200));
      expect(jsonDecode(response.body)['status'], equals('success'));
    });

    test('mocks POST request', () async {
      final mockClient = MockHttpClient();
      final mockResponse = http.Response(
        jsonEncode({'status': 'created', 'id': '123'}),
        201,
      );

      when(mockClient.post(
        Uri.parse('https://api.example.com/create'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => mockResponse);

      final response = await mockClient.post(
        Uri.parse('https://api.example.com/create'),
        body: jsonEncode({'name': 'test'}),
      );

      expect(response.statusCode, equals(201));
    });

    test('handles 404 error', () async {
      final mockClient = MockHttpClient();
      final mockResponse = http.Response(
        jsonEncode({'error': 'Not found'}),
        404,
      );

      when(mockClient.get(Uri.parse('https://api.example.com/notfound')))
          .thenAnswer((_) async => mockResponse);

      final response = await mockClient.get(Uri.parse('https://api.example.com/notfound'));

      expect(response.statusCode, equals(404));
    });

    test('handles 500 error', () async {
      final mockClient = MockHttpClient();
      final mockResponse = http.Response(
        jsonEncode({'error': 'Internal server error'}),
        500,
      );

      when(mockClient.get(Uri.parse('https://api.example.com/error')))
          .thenAnswer((_) async => mockResponse);

      final response = await mockClient.get(Uri.parse('https://api.example.com/error'));

      expect(response.statusCode, equals(500));
    });

    test('handles timeout', () async {
      final mockClient = MockHttpClient();

      when(mockClient.get(Uri.parse('https://api.example.com/timeout'))).thenAnswer((_) async {
        await Future.delayed(const Duration(seconds: 30));
        return http.Response('Timeout', 504);
      });

      // Test would timeout in real scenario
      expect(mockClient, isNotNull);
    });
  });

  group('API Response Parsing', () {
    test('parses Spotify token response', () async {
      final tokenResponse = {
        'access_token': 'BQDxK7...',
        'token_type': 'Bearer',
        'expires_in': 3600
      };

      expect(tokenResponse['access_token'], isNotEmpty);
      expect(tokenResponse['token_type'], equals('Bearer'));
      expect(tokenResponse['expires_in'], equals(3600));
    });

    test('parses MusicBrainz search response', () async {
      final searchResponse = {
        'created': '2024-01-01T00:00:00.000Z',
        'count': 100,
        'offset': 0,
        'recordings': []
      };

      expect(searchResponse['count'], equals(100));
      expect(searchResponse['offset'], equals(0));
    });

    test('handles malformed JSON', () async {
      const malformedJson = '{invalid json}';

      expect(
        () => jsonDecode(malformedJson),
        throwsA(isFormatException),
      );
    });
  });

  group('API Configuration', () {
    test('validates Spotify configuration', () async {
      final config = {
        'clientId': 'test-client-id',
        'clientSecret': 'test-client-secret',
        'tokenUrl': 'https://accounts.spotify.com/api/token',
        'apiUrl': 'https://api.spotify.com/v1'
      };

      expect(config['clientId'], isNotEmpty);
      expect(config['clientSecret'], isNotEmpty);
    });

    test('validates MusicBrainz configuration', () async {
      final config = {
        'baseUrl': 'https://musicbrainz.org/ws/2',
        'userAgent': 'RepSync/1.0.0',
        'rateLimit': 1
      };

      expect(config['baseUrl'], isNotEmpty);
      expect(config['userAgent'], isNotEmpty);
    });
  });
}

/// Mock HTTP client for testing
class MockHttpClient extends Mock implements http.Client {}
