import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/canonical_song.dart';
import '../../providers/data/data_providers.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/canonical_import.dart';
import '../../utils/snackbar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/standard_screen_scaffold.dart';

/// Browse the shared canonical catalog and copy songs into the personal
/// library (#59). Imported copies keep their [Song.canonicalSongId] link, so
/// they materialize through the linked-song save path.
class CanonicalBrowseScreen extends ConsumerStatefulWidget {
  const CanonicalBrowseScreen({super.key});

  @override
  ConsumerState<CanonicalBrowseScreen> createState() =>
      _CanonicalBrowseScreenState();
}

class _CanonicalBrowseScreenState extends ConsumerState<CanonicalBrowseScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<CanonicalSong> _results = const [];
  bool _loading = false;
  bool _searched = false;
  final _importing = <String>{};
  final _imported = <String>{};

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(q));
  }

  Future<void> _search(String q) async {
    final query = q.trim();
    if (query.length < 2) {
      setState(() {
        _results = const [];
        _searched = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final repo = ref.read(canonicalSongRepositoryProvider);
      final results = await repo.search(query: query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
        _searched = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAppSnackBar(context, 'Catalog search failed: $e');
    }
  }

  Future<void> _import(CanonicalSong c) async {
    setState(() => _importing.add(c.id));
    try {
      final song = canonicalToSong(c);
      await ref.read(songRepositoryProvider).saveSong(song);
      if (!mounted) return;
      setState(() {
        _importing.remove(c.id);
        _imported.add(c.id);
      });
      showAppSnackBar(context, 'Added "${c.title}" to your songs');
    } catch (e) {
      if (!mounted) return;
      setState(() => _importing.remove(c.id));
      showAppSnackBar(context, 'Import failed: $e');
    }
  }

  String _subtitle(CanonicalSong c) => [
    if (c.artist.isNotEmpty) c.artist,
    if (c.baseKey != null) c.baseKey!,
    if (c.baseBpm != null) '${c.baseBpm} BPM',
    if (c.baseSections.isNotEmpty) '${c.baseSections.length} sections',
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    return StandardScreenScaffold(
      title: 'Song catalog',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(MonoPulseSpacing.lg),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                hintText: 'Search the catalog…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (!_searched) {
      return const EmptyState(
        icon: Icons.library_music_outlined,
        message: 'Browse the shared catalog',
        hint:
            'Search songs other FlowGroove users have added, and copy one '
            'into your library — key, BPM and structure included.',
      );
    }
    if (_results.isEmpty && !_loading) {
      return const EmptyState(
        icon: Icons.search_off,
        message: 'No catalog matches',
        hint: 'Try a different title — or add the song yourself and it '
            'joins the catalog for everyone.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final c = _results[i];
        final busy = _importing.contains(c.id);
        final done = _imported.contains(c.id);
        return ListTile(
          title: Text(c.displayTitle),
          subtitle: Text(_subtitle(c)),
          trailing: done
              ? const Icon(Icons.check_circle,
                  color: MonoPulseColors.accentOrange)
              : busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : FilledButton.tonalIcon(
                      onPressed: () => _import(c),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                    ),
        );
      },
    );
  }
}
