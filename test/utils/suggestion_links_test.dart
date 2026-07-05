import 'package:flowgroove/models/link.dart';
import 'package:flowgroove/models/song_suggestion.dart';
import 'package:flowgroove/utils/suggestion_links.dart';
import 'package:flutter_test/flutter_test.dart';

SongSuggestion suggestion({String? mbId, String? spotifyId}) => SongSuggestion(
      id: 'x',
      title: 'Go With the Flow',
      artist: 'Queens of the Stone Age',
      source: SuggestionSource.musicbrainz,
      type: SuggestionType.exact,
      musicBrainzId: mbId,
      spotifyId: spotifyId,
    );

void main() {
  test('always adds YouTube, Chords and Lyrics search links', () {
    final links = linksForSuggestion(suggestion());
    final titles = links.map((l) => l.title).toSet();
    expect(titles, containsAll(<String>['YouTube', 'Chords', 'Lyrics']));
  });

  test('search URLs are query-encoded', () {
    final yt = linksForSuggestion(suggestion())
        .firstWhere((l) => l.title == 'YouTube');
    expect(yt.url, contains('search_query=Queens'));
    expect(yt.url, contains('Stone+Age'));
  });

  test('MusicBrainz link only when an ID is present', () {
    expect(
      linksForSuggestion(suggestion()).any((l) => l.title == 'MusicBrainz'),
      isFalse,
    );
    final withId = linksForSuggestion(suggestion(mbId: 'abc-123'));
    final mb = withId.firstWhere((l) => l.title == 'MusicBrainz');
    expect(mb.url, 'https://musicbrainz.org/recording/abc-123');
  });

  test('Spotify link only when an ID is present, using spotify type', () {
    expect(
      linksForSuggestion(suggestion()).any((l) => l.title == 'Spotify'),
      isFalse,
    );
    final sp = linksForSuggestion(suggestion(spotifyId: 'trk1'))
        .firstWhere((l) => l.title == 'Spotify');
    expect(sp.type, Link.typeSpotify);
    expect(sp.url, 'https://open.spotify.com/track/trk1');
  });
}
