import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/song.dart';
import '../../models/song_duplicate.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../services/matching/song_duplicate_detector.dart';
import '../../services/song_library_merge_service.dart';
import '../../utils/snackbar.dart';
import '../../widgets/menu_items_scope.dart';
import 'song_merge_dialog.dart';

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
                    child: matches.isEmpty
                        ? const Center(child: Text('No duplicate songs found.'))
                        : ListView.builder(
                            itemCount: matches.length,
                            itemBuilder: (context, index) =>
                                _buildMatch(matches[index]),
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

  Widget _buildMatch(SongDuplicateCandidate match) {
    return ListTile(
      title: Text('${match.source.title} / ${match.match.title}'),
      subtitle: Text(
        '${match.source.artist} / ${match.match.artist} - ${match.score.toStringAsFixed(0)}%${match.variantMismatch ? ' - different variants' : ''}',
      ),
      trailing: Wrap(
        children: [
          TextButton(
            onPressed: () => _dismiss(match),
            child: const Text('Not duplicate'),
          ),
          FilledButton(
            onPressed: () => _merge(match),
            child: const Text('Review merge'),
          ),
        ],
      ),
    );
  }

  Future<void> _dismiss(SongDuplicateCandidate match) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;
    await _service.dismissPair(user.uid, match.pairKey);
    if (mounted) setState(() => _dismissed.add(match.pairKey));
  }

  Future<void> _merge(SongDuplicateCandidate match) async {
    final result = await showDialog<(Song, Song, Song)>(
      context: context,
      builder: (_) => SongMergeDialog(first: match.source, second: match.match),
    );
    if (result == null || !mounted) return;
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;
    await _service.merge(
      uid: user.uid,
      keeperBefore: result.$1,
      duplicate: result.$2,
      merged: result.$3,
      setlists: ref.read(setlistsProvider).value ?? [],
      songRepository: ref.read(songRepositoryProvider),
      setlistRepository: ref.read(setlistRepositoryProvider),
    );
    ref.invalidate(songsProvider);
    ref.invalidate(setlistsProvider);
    if (mounted) {
      showAppSnackBar(context, 'Songs merged.');
    }
  }
}
