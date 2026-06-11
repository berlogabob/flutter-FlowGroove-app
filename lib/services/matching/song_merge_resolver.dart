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
