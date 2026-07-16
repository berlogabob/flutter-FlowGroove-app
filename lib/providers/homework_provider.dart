/// Aggregated "my homework" across the personal library (#68/#133): open
/// Song Lab tasks from every personal song, for the Practice screen.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song.dart';
import '../models/song_lab.dart';
import 'data/data_providers.dart';

class HomeworkItem {
  const HomeworkItem({required this.task, required this.song});
  final SongTask task;
  final Song song;
}

final myHomeworkProvider = FutureProvider.autoDispose<List<HomeworkItem>>((
  ref,
) async {
  final songs = await ref.watch(songsProvider.future);
  final repo = ref.watch(labRepositoryProvider);

  // ponytail: N one-shot reads — fine for library-sized N; a collection-group
  // query (index + rules) when it hurts.
  final items = <HomeworkItem>[];
  for (final song in songs) {
    final tasks = await repo.listOpenTasks(song.id);
    items.addAll(tasks.map((t) => HomeworkItem(task: t, song: song)));
  }

  // Due-dated first (soonest), then priority, then newest.
  items.sort((a, b) {
    final ad = a.task.dueAt;
    final bd = b.task.dueAt;
    if (ad != null && bd != null) return ad.compareTo(bd);
    if (ad != null) return -1;
    if (bd != null) return 1;
    final p = b.task.priority.compareTo(a.task.priority);
    if (p != 0) return p;
    return b.task.createdAt.compareTo(a.task.createdAt);
  });
  return items;
});
