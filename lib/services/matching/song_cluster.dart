import '../../models/song.dart';
import '../../models/song_duplicate.dart';

/// Cluster of mutually-similar songs (#81): pairwise duplicate candidates
/// folded into connected components (union-find), so "3 versions of Hey Joe"
/// is one cluster to merge in one pass — not three pairs.
class SongCluster {
  const SongCluster({
    required this.songs,
    required this.pairKeys,
    required this.maxScore,
  });

  /// Oldest-first (stable identity: the keeper defaults to the first).
  final List<Song> songs;

  /// Every pairwise key inside the cluster — dismissing the cluster
  /// dismisses them all.
  final Set<String> pairKeys;
  final double maxScore;
}

/// Union-find over the pairwise candidates.
List<SongCluster> clusterCandidates(List<SongDuplicateCandidate> matches) {
  final parent = <String, String>{};
  final songsById = <String, Song>{};

  String find(String id) {
    var root = id;
    while (parent[root] != root) {
      root = parent[root]!;
    }
    // Path compression.
    var cursor = id;
    while (parent[cursor] != root) {
      final next = parent[cursor]!;
      parent[cursor] = root;
      cursor = next;
    }
    return root;
  }

  void union(String a, String b) {
    parent.putIfAbsent(a, () => a);
    parent.putIfAbsent(b, () => b);
    final ra = find(a);
    final rb = find(b);
    if (ra != rb) parent[rb] = ra;
  }

  for (final m in matches) {
    songsById[m.source.id] = m.source;
    songsById[m.match.id] = m.match;
    union(m.source.id, m.match.id);
  }

  final byRoot = <String, List<Song>>{};
  for (final id in parent.keys) {
    byRoot.putIfAbsent(find(id), () => []).add(songsById[id]!);
  }

  final clusters = <SongCluster>[];
  for (final entry in byRoot.entries) {
    final members = entry.value
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final ids = members.map((s) => s.id).toSet();
    final related = matches
        .where((m) => ids.contains(m.source.id) && ids.contains(m.match.id))
        .toList();
    clusters.add(
      SongCluster(
        songs: members,
        pairKeys: related.map((m) => m.pairKey).toSet(),
        maxScore: related.fold<double>(
          0,
          (mx, m) => m.score > mx ? m.score : mx,
        ),
      ),
    );
  }
  // Biggest/most confident first.
  clusters.sort((a, b) {
    final size = b.songs.length.compareTo(a.songs.length);
    return size != 0 ? size : b.maxScore.compareTo(a.maxScore);
  });
  return clusters;
}
