import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/models/musicbrainz_recording.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/models/song_suggestion.dart';
import 'package:flowgroove/repositories/song_repository.dart';
import 'package:flowgroove/services/musicbrainz_service.dart';
import 'package:flowgroove/services/song_suggestion_service.dart';

/// MusicBrainz stub returning a fixed recording list (no network).
class _FakeMusicBrainz extends MusicBrainzService {
  _FakeMusicBrainz(this.recordings);
  final List<MusicBrainzRecording> recordings;

  @override
  Future<List<MusicBrainzRecording>> searchRecording({
    required String title,
    String? artist,
    int limit = 10,
    int offset = 0,
  }) async => recordings;
}

/// Song repository stub — only getSongs is exercised here.
class _EmptySongRepo implements SongRepository {
  @override
  Future<List<Song>> getSongs(String uid) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

MusicBrainzRecording _rec(String id, String title) =>
    MusicBrainzRecording(id: id, title: title);

void main() {
  test('#75: MusicBrainz results are fuzzy-scored, so off-query (Cyrillic) '
      'recordings are filtered out and the real match survives', () async {
    final service = SongSuggestionService(
      songRepo: _EmptySongRepo(),
      musicBrainz: _FakeMusicBrainz([
        _rec('mb-1', 'Hit the Road Jack'),
        _rec('mb-2', 'Привет, как дела'), // unrelated Cyrillic title
        _rec('mb-3', 'Совсем другая песня'), // another unrelated Cyrillic title
      ]),
      userId: 'u1',
    );

    final results = await service.getSuggestions(query: 'hit the road jack');

    final titles = results.map((s) => s.title).toList();
    expect(titles, contains('Hit the Road Jack'));
    expect(titles, isNot(contains('Привет, как дела')));
    expect(titles, isNot(contains('Совсем другая песня')));

    // Score reflects the real fuzzy match, not the old flat 0.85.
    final hit = results.firstWhere((s) => s.title == 'Hit the Road Jack');
    expect(hit.matchScore, greaterThanOrEqualTo(0.6));
  });

  test('a clearly different Latin query does not surface an unrelated title',
      () async {
    final service = SongSuggestionService(
      songRepo: _EmptySongRepo(),
      musicBrainz: _FakeMusicBrainz([_rec('mb-1', 'Hit the Road Jack')]),
      userId: 'u1',
    );

    final results = await service.getSuggestions(query: 'bohemian rhapsody');
    expect(results.map((s) => s.title), isNot(contains('Hit the Road Jack')));
  });

  test('#76: SongSuggestion.fromSpotify carries source + spotifyId for autofill',
      () {
    final s = SongSuggestion.fromSpotify(
      id: 't1',
      title: 'Zombie',
      artist: 'The Cranberries',
      spotifyId: 't1',
    );
    expect(s.source, SuggestionSource.spotify);
    expect(s.spotifyId, 't1');
    expect(s.id, 'spotify_t1');
  });
}
