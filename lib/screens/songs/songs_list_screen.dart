import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/data_providers.dart';
import '../../providers/auth_provider.dart';
import '../../models/song.dart';
import '../../widgets/song_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/confirmation_dialog.dart';

/// Screen for displaying the list of songs with search functionality.
///
/// This screen shows all songs for the current user with the ability
/// to search by title, artist, or tags.
class SongsListScreen extends ConsumerStatefulWidget {
  const SongsListScreen({super.key});

  @override
  ConsumerState<SongsListScreen> createState() => _SongsListScreenState();
}

class _SongsListScreenState extends ConsumerState<SongsListScreen> {
  String _searchQuery = '';

  /// Filter songs based on the search query.
  ///
  /// Searches in title, artist, and tags (case-insensitive).
  List<Song> _filterSongs(List<Song> songs) {
    if (_searchQuery.trim().isEmpty) {
      return songs;
    }

    final query = _searchQuery.toLowerCase().trim();
    return songs.where((song) {
      final titleMatch = song.title.toLowerCase().contains(query);
      final artistMatch = song.artist.toLowerCase().contains(query);
      final tagsMatch = song.tags.any((tag) => tag.toLowerCase().contains(query));
      return titleMatch || artistMatch || tagsMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Songs')),
      body: songsAsync.when(
        data: (songs) => _buildContent(context, ref, songs),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/add-song'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, List<Song> songs) {
    final filteredSongs = _filterSongs(songs);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: CustomTextField(
            hint: 'Search songs...',
            prefixIcon: Icons.search,
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        Expanded(
          child: filteredSongs.isEmpty
              ? _buildEmptyState(songs.isEmpty)
              : ListView.builder(
                  itemCount: filteredSongs.length,
                  itemBuilder: (context, index) {
                    final song = filteredSongs[index];
                    return _buildSongCard(context, ref, song);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isEmpty) {
    if (isEmpty) {
      return EmptyState.songs(
        onAdd: () => Navigator.pushNamed(context, '/add-song'),
      );
    }
    return EmptyState.search(query: _searchQuery);
  }

  Widget _buildSongCard(BuildContext context, WidgetRef ref, Song song) {
    return Dismissible(
      key: Key(song.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await ConfirmationDialog.showDeleteDialog(
          context,
          title: 'Delete Song',
          message: 'Are you sure you want to delete this song?',
          confirmLabel: 'Delete',
        );
      },
      onDismissed: (direction) async {
        final user = ref.read(currentUserProvider);
        if (user != null) {
          await ref.read(firestoreProvider).deleteSong(song.id, user.uid);
        }
      },
      child: SongCard(
        song: song,
        onEdit: () =>
            Navigator.pushNamed(context, '/edit-song', arguments: song),
        onPlaySpotify: () async {
          if (song.spotifyUrl != null) {
            final uri = Uri.parse(song.spotifyUrl!);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
        },
      ),
    );
  }
}
