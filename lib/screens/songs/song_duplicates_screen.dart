import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/song.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../services/matching/song_cluster.dart';
import '../../services/matching/song_duplicate_detector.dart';
import '../../services/song_library_merge_service.dart';
import '../../utils/snackbar.dart';
import '../../widgets/menu_items_scope.dart';
import 'song_cluster_merge_screen.dart';

/// Duplicate songs, clustered (#81): similar songs group into one cluster
/// card ("3 versions"), merged in one pass through the field×song matrix —
/// no more pairwise whack-a-mole.
class SongDuplicatesScreen extends ConsumerStatefulWidget {
  const SongDuplicatesScreen({super.key});

  @override
  ConsumerState<SongDuplicatesScreen> createState() =>
      _SongDuplicatesScreenState();
}

class _SongDuplicatesScreenState extends ConsumerState<SongDuplicatesScreen> {
  final _detector = const SongDuplicateDetector();
  bool _includePossible = false;
  Set<String> _dismissed = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadDismissals);
  }

  SongLibraryMergeService get _service =>
      SongLibraryMergeService(firestore: ref.read(firebaseFirestoreProvider));

  Future<void> _loadDismissals() async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;
    final dismissed = await _service.loadDismissedPairs(user.uid);
    if (mounted) setState(() => _dismissed = dismissed);
  }

  @override
  Widget build(BuildContext context) {
    final songs = ref.watch(songsProvider);
    // Pushed branch child: title is published for the shell's bottom bar
    // ([← Back] [title] [⋮ Menu]); there is no top app bar.
    return MenuScopePublisher(
      data: const MenuScopeData(title: 'Duplicate songs'),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: songs.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('Could not load songs: $error')),
            data: (items) {
              final matches = _detector
                  .findLibraryDuplicates(
                    items,
                    includePossible: _includePossible,
                  )
                  .where((match) => !_dismissed.contains(match.pairKey))
                  .toList();
              final clusters = clusterCandidates(matches);
              return Column(
                children: [
                  SwitchListTile(
                    title: const Text('Include possible matches'),
                    subtitle: const Text(
                      'Shows matches scoring 70-84% and variant conflicts.',
                    ),
                    value: _includePossible,
                    onChanged: (value) =>
                        setState(() => _includePossible = value),
                  ),
                  Expanded(
                    child: clusters.isEmpty
                        ? const Center(child: Text('No duplicate songs found.'))
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 96),
                            itemCount: clusters.length,
                            itemBuilder: (context, index) =>
                                _clusterCard(clusters[index]),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _clusterCard(SongCluster cluster) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${cluster.songs.length} similar songs · '
              '${cluster.maxScore.toStringAsFixed(0)}% match',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            for (final s in cluster.songs)
              Text(
                '• ${s.title} — ${s.artist}'
                '${s.canonicalSongId != null ? '  (linked)' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _dismissCluster(cluster),
                  child: const Text('Not duplicates'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _mergeCluster(cluster),
                  child: const Text('Merge…'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _dismissCluster(SongCluster cluster) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;
    for (final key in cluster.pairKeys) {
      await _service.dismissPair(user.uid, key);
    }
    if (mounted) setState(() => _dismissed.addAll(cluster.pairKeys));
  }

  Future<void> _mergeCluster(SongCluster cluster) async {
    final merged = await Navigator.of(context).push<Song>(
      MaterialPageRoute(
        builder: (_) => SongClusterMergeScreen(songs: cluster.songs),
      ),
    );
    if (merged == null || !mounted) return;
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    final duplicates = cluster.songs.where((s) => s.id != merged.id).toList();
    await _service.mergeCluster(
      uid: user.uid,
      keeperBefore: cluster.songs.firstWhere((s) => s.id == merged.id),
      duplicates: duplicates,
      merged: merged,
      setlists: ref.read(setlistsProvider).value ?? [],
      songRepository: ref.read(songRepositoryProvider),
      setlistRepository: ref.read(setlistRepositoryProvider),
    );
    ref.invalidate(songsProvider);
    ref.invalidate(setlistsProvider);
    if (mounted) {
      showAppSnackBar(
        context,
        'Merged ${cluster.songs.length} songs into "${merged.title}".',
      );
    }
  }
}
