import '../../models/link.dart';
import '../../models/song.dart';

enum SongMergeSide { keeper, duplicate }

class SongMergeChoices {
  const SongMergeChoices({
    this.title = SongMergeSide.keeper,
    this.artist = SongMergeSide.keeper,
    this.originalKey = SongMergeSide.keeper,
    this.originalBpm = SongMergeSide.keeper,
    this.ourKey = SongMergeSide.keeper,
    this.ourBpm = SongMergeSide.keeper,
    this.notes = SongMergeSide.keeper,
    this.arrangement = SongMergeSide.keeper,
  });

  final SongMergeSide title;
  final SongMergeSide artist;
  final SongMergeSide originalKey;
  final SongMergeSide originalBpm;
  final SongMergeSide ourKey;
  final SongMergeSide ourBpm;
  final SongMergeSide notes;
  final SongMergeSide arrangement;
}

/// Matrix-mergeable fields (#81): each picks its value from ONE cluster
/// member; tags and links always union across all members.
enum ClusterField {
  title,
  artist,
  originalKey,
  originalBpm,
  ourKey,
  ourBpm,
  notes,
  arrangement,
}

class SongMergeResolver {
  const SongMergeResolver();

  Song preferredKeeper(Song first, Song second) {
    if (first.canonicalSongId != null && second.canonicalSongId == null) {
      return first;
    }
    if (second.canonicalSongId != null && first.canonicalSongId == null) {
      return second;
    }
    return first.createdAt.isBefore(second.createdAt) ? first : second;
  }

  /// Keeper of a whole cluster: canonical-linked wins, then oldest.
  Song preferredKeeperOfMany(List<Song> songs) => songs.reduce(preferredKeeper);

  /// N-way merge (#81): [picks] maps each field to an index into [songs];
  /// unmapped fields default to the [keeper]'s value. Tags/links union
  /// across every member; createdAt is the earliest.
  Song mergeCluster(
    List<Song> songs, {
    required Song keeper,
    Map<ClusterField, int> picks = const {},
    DateTime? now,
  }) {
    Song pick(ClusterField f) =>
        picks.containsKey(f) ? songs[picks[f]!] : keeper;

    var tags = keeper.tags;
    var links = keeper.links;
    var earliest = keeper.createdAt;
    for (final s in songs) {
      if (identical(s, keeper) || s.id == keeper.id) continue;
      tags = _mergeTags(tags, s.tags);
      links = _mergeLinks(links, s.links);
      if (s.createdAt.isBefore(earliest)) earliest = s.createdAt;
    }

    final arrangement = pick(ClusterField.arrangement);
    return keeper.copyWith(
      title: pick(ClusterField.title).title,
      artist: pick(ClusterField.artist).artist,
      originalKey: pick(ClusterField.originalKey).originalKey,
      originalBPM: pick(ClusterField.originalBpm).originalBPM,
      ourKey: pick(ClusterField.ourKey).ourKey,
      ourBPM: pick(ClusterField.ourBpm).ourBPM,
      notes: pick(ClusterField.notes).notes,
      tags: tags,
      links: links,
      sections: arrangement.sections,
      accentBeats: arrangement.accentBeats,
      regularBeats: arrangement.regularBeats,
      beatModes: arrangement.beatModes,
      createdAt: earliest,
      updatedAt: now ?? DateTime.now(),
    );
  }

  Song merge(
    Song keeper,
    Song duplicate, {
    SongMergeChoices choices = const SongMergeChoices(),
    DateTime? now,
  }) {
    T choose<T>(SongMergeSide side, T keeperValue, T duplicateValue) =>
        side == SongMergeSide.keeper ? keeperValue : duplicateValue;

    return keeper.copyWith(
      title: choose(choices.title, keeper.title, duplicate.title),
      artist: choose(choices.artist, keeper.artist, duplicate.artist),
      originalKey: choose(
        choices.originalKey,
        keeper.originalKey,
        duplicate.originalKey,
      ),
      originalBPM: choose(
        choices.originalBpm,
        keeper.originalBPM,
        duplicate.originalBPM,
      ),
      ourKey: choose(choices.ourKey, keeper.ourKey, duplicate.ourKey),
      ourBPM: choose(choices.ourBpm, keeper.ourBPM, duplicate.ourBPM),
      notes: choose(choices.notes, keeper.notes, duplicate.notes),
      tags: _mergeTags(keeper.tags, duplicate.tags),
      links: _mergeLinks(keeper.links, duplicate.links),
      sections: choose(
        choices.arrangement,
        keeper.sections,
        duplicate.sections,
      ),
      accentBeats: choose(
        choices.arrangement,
        keeper.accentBeats,
        duplicate.accentBeats,
      ),
      regularBeats: choose(
        choices.arrangement,
        keeper.regularBeats,
        duplicate.regularBeats,
      ),
      beatModes: choose(
        choices.arrangement,
        keeper.beatModes,
        duplicate.beatModes,
      ),
      createdAt: keeper.createdAt.isBefore(duplicate.createdAt)
          ? keeper.createdAt
          : duplicate.createdAt,
      updatedAt: now ?? DateTime.now(),
    );
  }

  /// Merge a transient imported row into a persisted library song.
  /// Existing non-empty library values remain authoritative.
  Song mergeImport(Song librarySong, Song imported, {DateTime? now}) {
    String? fillString(String? current, String? incoming) =>
        current == null || current.trim().isEmpty ? incoming : current;
    int? fillInt(int? current, int? incoming) => current ?? incoming;
    final libraryHasArrangement =
        librarySong.sections.isNotEmpty || librarySong.beatModes.isNotEmpty;

    return librarySong.copyWith(
      title: librarySong.title.trim().isEmpty
          ? imported.title
          : librarySong.title,
      artist: librarySong.artist.trim().isEmpty
          ? imported.artist
          : librarySong.artist,
      originalKey: fillString(librarySong.originalKey, imported.originalKey),
      originalBPM: fillInt(librarySong.originalBPM, imported.originalBPM),
      ourKey: fillString(librarySong.ourKey, imported.ourKey),
      ourBPM: fillInt(librarySong.ourBPM, imported.ourBPM),
      notes: fillString(librarySong.notes, imported.notes),
      spotifyUrl: fillString(librarySong.spotifyUrl, imported.spotifyUrl),
      spotifyId: fillString(librarySong.spotifyId, imported.spotifyId),
      musicbrainzId: fillString(
        librarySong.musicbrainzId,
        imported.musicbrainzId,
      ),
      isrc: fillString(librarySong.isrc, imported.isrc),
      deezerId: fillString(librarySong.deezerId, imported.deezerId),
      album: fillString(librarySong.album, imported.album),
      durationMs: fillInt(librarySong.durationMs, imported.durationMs),
      tags: _mergeTags(librarySong.tags, imported.tags),
      links: _mergeLinks(librarySong.links, imported.links),
      sections: libraryHasArrangement
          ? librarySong.sections
          : imported.sections,
      accentBeats: libraryHasArrangement
          ? librarySong.accentBeats
          : imported.accentBeats,
      regularBeats: libraryHasArrangement
          ? librarySong.regularBeats
          : imported.regularBeats,
      beatModes: libraryHasArrangement
          ? librarySong.beatModes
          : imported.beatModes,
      updatedAt: now ?? DateTime.now(),
    );
  }

  List<String> _mergeTags(List<String> first, List<String> second) {
    final result = <String>[];
    final seen = <String>{};
    for (final tag in [...first, ...second]) {
      if (seen.add(tag.trim().toLowerCase())) result.add(tag.trim());
    }
    return result.where((tag) => tag.isNotEmpty).toList();
  }

  List<Link> _mergeLinks(List<Link> first, List<Link> second) {
    final result = <Link>[];
    final seen = <String>{};
    for (final link in [...first, ...second]) {
      final normalized = link.url.trim().toLowerCase().replaceFirst(
        RegExp(r'/$'),
        '',
      );
      if (normalized.isNotEmpty && seen.add(normalized)) result.add(link);
    }
    return result;
  }
}
