import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data_providers.dart';
import '../../providers/auth_provider.dart';
import '../../models/setlist.dart';
import '../../models/song.dart';
import '../../services/pdf_service.dart';
import '../../widgets/setlist_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/confirmation_dialog.dart';

/// Screen for displaying the list of setlists with search functionality.
///
/// This screen shows all setlists with the ability to search by name
/// and description.
class SetlistsListScreen extends ConsumerStatefulWidget {
  const SetlistsListScreen({super.key});

  @override
  ConsumerState<SetlistsListScreen> createState() => _SetlistsListScreenState();
}

class _SetlistsListScreenState extends ConsumerState<SetlistsListScreen> {
  String _searchQuery = '';

  /// Filter setlists based on the search query.
  ///
  /// Searches in name and description (case-insensitive).
  List<Setlist> _filterSetlists(List<Setlist> setlists) {
    if (_searchQuery.trim().isEmpty) {
      return setlists;
    }

    final query = _searchQuery.toLowerCase().trim();
    return setlists.where((setlist) {
      final nameMatch = setlist.name.toLowerCase().contains(query);
      final descMatch =
          setlist.description?.toLowerCase().contains(query) ?? false;
      return nameMatch || descMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final setlistsAsync = ref.watch(setlistsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Setlists')),
      body: setlistsAsync.when(
        data: (setlists) => _buildContent(context, ref, setlists),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/create-setlist'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<Setlist> setlists,
  ) {
    final filteredSetlists = _filterSetlists(setlists);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: CustomTextField(
            hint: 'Search setlists...',
            prefixIcon: Icons.search,
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        Expanded(
          child: filteredSetlists.isEmpty
              ? _buildEmptyState(setlists.isEmpty)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredSetlists.length,
                  itemBuilder: (context, index) =>
                      _buildSetlistCard(context, ref, filteredSetlists[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isEmpty) {
    if (isEmpty) {
      return EmptyState.setlists(
        onCreate: () => Navigator.pushNamed(context, '/create-setlist'),
      );
    }
    return EmptyState.search(query: _searchQuery);
  }

  Widget _buildSetlistCard(
    BuildContext context,
    WidgetRef ref,
    Setlist setlist,
  ) {
    return SetlistCard(
      id: setlist.id,
      name: setlist.name,
      songCount: setlist.songIds.length,
      bandName: setlist.bandId,
      date: setlist.eventDate,
      onEdit: () =>
          Navigator.pushNamed(context, '/edit-setlist', arguments: setlist),
      onDelete: () => _confirmDelete(context, ref, setlist),
      onTap: () => _showExportOptions(context, ref, setlist),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Setlist setlist,
  ) async {
    final confirmed = await ConfirmationDialog.showDeleteDialog(
      context,
      title: 'Delete Setlist',
      message: 'Are you sure you want to delete this setlist?',
    );

    if (confirmed) {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        await ref.read(firestoreProvider).deleteSetlist(setlist.id, user.uid);
      }
    }
  }

  void _showExportOptions(
    BuildContext context,
    WidgetRef ref,
    Setlist setlist,
  ) {
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
