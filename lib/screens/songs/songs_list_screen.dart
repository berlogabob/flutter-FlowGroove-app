import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/data_providers.dart';
import '../../providers/auth_provider.dart';
import '../../models/song.dart';
import '../../models/band.dart';
import '../../theme/app_theme.dart';
import '../../widgets/song_attribution_badge.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/confirmation_dialog.dart';
import '../bands/band_songs_screen.dart';

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
      final tagsMatch = song.tags.any(
        (tag) => tag.toLowerCase().contains(query),
      );
      return titleMatch || artistMatch || tagsMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songsProvider);
    final bandsAsync = ref.watch(bandsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Songs'),
        actions: [
          // Button to view band songs
          bandsAsync.when(
            data: (bands) {
              if (bands.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.groups),
                onPressed: () => _showBandSelector(context, ref, bands),
                tooltip: 'Band Songs',
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (error, stack) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: songsAsync.when(
        data: (songs) => _buildContent(context, ref, songs, bandsAsync),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/add-song'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<Song> songs,
    AsyncValue<List<Band>> bandsAsync,
  ) {
    final filteredSongs = _filterSongs(songs);
    final bands = bandsAsync.value ?? [];

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
                    return _buildSongCard(context, ref, song, bands);
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

  Widget _buildSongCard(
    BuildContext context,
    WidgetRef ref,
    Song song,
    List<Band> bands,
  ) {
    final isShared = song.isCopy || song.bandId != null;

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
      child: InkWell(
        onTap: () =>
            Navigator.pushNamed(context, '/edit-song', arguments: song),
        onLongPress: bands.isNotEmpty
            ? () => _showAddToBandMenu(context, ref, song, bands)
            : null,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isShared
                  ? AppColors.color5.withValues(alpha: 0.3)
                  : AppColors.color1.withValues(alpha: 0.3),
              child: Icon(
                isShared ? Icons.content_copy : Icons.music_note,
                color: isShared ? AppColors.color5 : AppColors.color1,
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    song.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: isShared
                          ? TextDecoration.underline
                          : TextDecoration.none,
                      decorationColor: AppColors.color5,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: AttributionSubtitle(
              subtitle: song.artist,
              contributorName: song.contributedBy,
              isCopy: isShared,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (song.ourKey != null)
                  Text(
                    song.ourKey!,
                    style: const TextStyle(
                      color: AppColors.color5,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                if (song.ourBPM != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${song.ourBPM}',
                    style: const TextStyle(
                      color: AppColors.color5,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (song.spotifyUrl != null)
                  IconButton(
                    icon: const Icon(
                      Icons.play_circle_fill,
                      color: Colors.green,
                      size: 28,
                    ),
                    onPressed: () async {
                      final uri = Uri.parse(song.spotifyUrl!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    tooltip: 'Play on Spotify',
                  ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/edit-song',
                    arguments: song,
                  ),
                  tooltip: 'Edit',
                ),
                // Add to Band button (only if user has bands)
                if (bands.isNotEmpty)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.add_to_queue, size: 20),
                    tooltip: 'Add to Band',
                    onSelected: (bandId) =>
                        _addToBand(context, ref, song, bandId),
                    itemBuilder: (context) => [
                      // Show all bands as popup menu items
                      ...bands.map(
                        (band) => PopupMenuItem<String>(
                          value: band.id,
                          child: Row(
                            children: [
                              Icon(Icons.groups, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  band.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Show a menu to select a band for adding the song.
  void _showAddToBandMenu(
    BuildContext context,
    WidgetRef ref,
    Song song,
    List<Band> bands,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add to Band',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${song.title} - ${song.artist}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ...bands.map(
              (band) => ListTile(
                leading: const CircleAvatar(child: Icon(Icons.groups)),
                title: Text(band.name),
                subtitle: Text('${band.members.length} members'),
                onTap: () {
                  Navigator.pop(context);
                  _addToBand(context, ref, song, band.id);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Add a song to a band.
  Future<void> _addToBand(
    BuildContext context,
    WidgetRef ref,
    Song song,
    String bandId,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      await ref
          .read(firestoreProvider)
          .addSongToBand(
            song: song,
            bandId: bandId,
            contributorId: user.uid,
            contributorName: user.displayName ?? user.email ?? 'Unknown',
          );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${song.title}" to band'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding song: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show band selector for viewing band songs.
  void _showBandSelector(
    BuildContext context,
    WidgetRef ref,
    List<Band> bands,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Band',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...bands.map(
              (band) => ListTile(
                leading: const CircleAvatar(child: Icon(Icons.groups)),
                title: Text(band.name),
                subtitle: Text('${band.members.length} members'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BandSongsScreen(band: band),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
