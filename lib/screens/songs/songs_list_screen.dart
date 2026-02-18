import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data_providers.dart';
import '../../models/song.dart';
import '../../theme/app_theme.dart';

class SongsListScreen extends ConsumerStatefulWidget {
  const SongsListScreen({super.key});

  @override
  ConsumerState<SongsListScreen> createState() => _SongsListScreenState();
}

class _SongsListScreenState extends ConsumerState<SongsListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final songs = ref.watch(songsProvider);
    final filteredSongs = songs.where((song) {
      final query = _searchQuery.toLowerCase();
      return song.title.toLowerCase().contains(query) ||
          song.artist.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Songs')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search songs...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: filteredSongs.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: filteredSongs.length,
                    itemBuilder: (context, index) {
                      final song = filteredSongs[index];
                      return _buildSongCard(song);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/add-song'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_note, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No songs yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first song',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildSongCard(Song song) {
    return Dismissible(
      key: Key(song.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        ref.read(songsProvider.notifier).deleteSong(song.id);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${song.title} deleted')));
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
                    color: AppColors.color5.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${song.ourBPM}',
                    style: TextStyle(
                      color: AppColors.color5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (song.ourKey != null) ...[
                const SizedBox(width: 8),
                Text(
                  song.ourKey!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.color4,
                  ),
                ),
              ],
            ],
          ),
          onTap: () {
            Navigator.pushNamed(context, '/edit-song', arguments: song);
          },
        ),
      ),
    );
  }
}
