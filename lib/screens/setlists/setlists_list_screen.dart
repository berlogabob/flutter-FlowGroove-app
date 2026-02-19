import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data_providers.dart';
import '../../models/setlist.dart';
import '../../models/song.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';

class SetlistsListScreen extends ConsumerWidget {
  const SetlistsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setlistsAsync = ref.watch(setlistsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Setlists')),
      body: setlistsAsync.when(
        data: (setlists) => setlists.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: setlists.length,
                itemBuilder: (context, index) =>
                    _buildSetlistCard(context, ref, setlists[index]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/create-setlist'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.queue_music, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('No setlists yet', style: TextStyle(fontSize: 18)),
          SizedBox(height: 8),
          Text('Create a setlist for your gig'),
        ],
      ),
    );
  }

  Widget _buildSetlistCard(
    BuildContext context,
    WidgetRef ref,
    Setlist setlist,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.color3,
          child: const Icon(Icons.queue_music, color: AppColors.color4),
        ),
        title: Text(
          setlist.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${setlist.songIds.length} songs'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, size: 20),
              onPressed: () => _exportSetlist(context, ref, setlist),
              tooltip: 'Export PDF',
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => Navigator.pushNamed(
                context,
                '/edit-setlist',
                arguments: setlist,
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  void _exportSetlist(
    BuildContext context,
    WidgetRef ref,
    Setlist setlist,
  ) async {
    final songsAsync = ref.read(songsProvider);
    final allSongs = songsAsync.value ?? [];
    final setlistSongs = allSongs
        .where((s) => setlist.songIds.contains(s.id))
        .toList();

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Export as PDF'),
              subtitle: const Text('Generate printable PDF document'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await PdfService.exportSetlist(setlist, setlistSongs);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Share as Links'),
              subtitle: const Text('Copy song links to share'),
              onTap: () {
                Navigator.pop(context);
                _shareAsLinks(context, setlist, setlistSongs);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _shareAsLinks(BuildContext context, Setlist setlist, List<Song> songs) {
    final buffer = StringBuffer();
    buffer.writeln('🎵 ${setlist.name}');
    if (setlist.description != null) {
      buffer.writeln(setlist.description);
    }
    buffer.writeln();
    buffer.writeln('Songs:');
    for (int i = 0; i < songs.length; i++) {
      final song = songs[i];
      buffer.writeln('${i + 1}. ${song.title} - ${song.artist}');
      if (song.spotifyUrl != null) {
        buffer.writeln('   🎧 ${song.spotifyUrl}');
      } else {
        final searchUrl = Uri.encodeComponent('${song.title} ${song.artist}');
        buffer.writeln('   🔍 https://open.spotify.com/search/$searchUrl');
      }
    }
    buffer.writeln();
    buffer.writeln('Created with RepSync');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Setlist links copied to clipboard!')),
    );
  }
}
