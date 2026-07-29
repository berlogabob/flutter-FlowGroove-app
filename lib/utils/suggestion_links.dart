import '../models/link.dart';
import '../models/song_suggestion.dart';

/// Builds provenance links for an accepted [SongSuggestion] so the user can
/// see where the metadata came from and jump to each source.
///
/// MusicBrainz + Spotify are exact deep links (deterministic from the IDs the
/// suggestion already carries). YouTube/chords/lyrics are search links — we
/// have no exact IDs for those. The [Link.title] is the service name, which
/// the links editor renders alongside the type icon.
///
/// ponytail: reuses existing [Link] types (no new dropdown entries). Chords
/// link is an Ultimate Guitar search; there's no free chord API to deep-link.
List<Link> linksForSuggestion(SongSuggestion s) {
  final q = Uri.encodeQueryComponent('${s.artist} ${s.title}'.trim());
  return [
    if (s.musicBrainzId != null && s.musicBrainzId!.isNotEmpty)
      Link(
        type: Link.typeOther,
        url: 'https://musicbrainz.org/recording/${s.musicBrainzId}',
        title: 'MusicBrainz',
      ),
    if (s.spotifyId != null && s.spotifyId!.isNotEmpty)
      Link(
        type: Link.typeSpotify,
        url: 'https://open.spotify.com/track/${s.spotifyId}',
        title: 'Spotify',
      ),
    Link(
      type: Link.typeYoutubeOriginal,
      url: 'https://www.youtube.com/results?search_query=$q',
      title: 'YouTube',
    ),
    Link(
      type: Link.typeChords,
      url: 'https://www.ultimate-guitar.com/search.php?search_type=title&value=$q',
      title: 'Chords',
    ),
    Link(
      type: Link.typeOther,
      url: 'https://www.google.com/search?q=$q+lyrics',
      title: 'Lyrics',
    ),
  ];
}
