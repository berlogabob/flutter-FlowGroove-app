import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data_providers.dart';
import '../../providers/auth_provider.dart';
import '../../models/song.dart';
import '../../theme/app_theme.dart';

class SongsListScreen extends ConsumerWidget {
  const SongsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search songs...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              // Simple filter - in real app would use a search provider
            },
          ),
        ),
        Expanded(
          child: songs.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return _buildSongCard(context, ref, song);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_note, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('No songs yet', style: TextStyle(fontSize: 18)),
          SizedBox(height: 8),
          Text('Tap + to add your first song'),
        ],
      ),
    );
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
      onDismissed: (direction) async {
        final user = ref.read(currentUserProvider);
        if (user != null) {
          await ref.read(firestoreProvider).deleteSong(song.id, user.uid);
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.color1,
            child: const Icon(Icons.music_note, color: Colors.white),
          ),
          title: Text(song.title),
          subtitle: Text(song.artist),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (song.ourBPM != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.color5.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${song.ourBPM}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              if (song.ourKey != null) ...[
                const SizedBox(width: 8),
                Text(
                  song.ourKey!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () =>
                    Navigator.pushNamed(context, '/edit-song', arguments: song),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
