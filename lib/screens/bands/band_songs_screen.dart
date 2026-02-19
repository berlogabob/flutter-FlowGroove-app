import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/song.dart';
import '../../../models/band.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/song_attribution_badge.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../widgets/confirmation_dialog.dart';

/// Screen for displaying a band's shared songs.
///
/// This screen shows all songs that have been shared to the band's
/// song bank, with filtering by contributor and attribution badges.
class BandSongsScreen extends ConsumerStatefulWidget {
  /// The band whose songs to display.
  final Band band;

  const BandSongsScreen({super.key, required this.band});

  @override
  ConsumerState<BandSongsScreen> createState() => _BandSongsScreenState();
}

class _BandSongsScreenState extends ConsumerState<BandSongsScreen> {
  String _searchQuery = '';
  String? _filterContributor;

  /// Get the current user's role in the band.
  String? get _userRole {
    final user = ref.read(currentUserProvider);
    if (user == null) return null;

    final member = widget.band.members.firstWhere(
      (m) => m.uid == user.uid,
      orElse: () => BandMember(uid: '', role: ''),
    );
    return member.role;
  }

  /// Check if the current user can edit band songs.
  bool get _canEdit {
    final role = _userRole;
    return role == BandMember.roleAdmin || role == BandMember.roleEditor;
  }

  /// Filter songs based on search query and contributor filter.
  List<Song> _filterSongs(List<Song> songs) {
    var filtered = songs;

    // Apply search filter
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      filtered = filtered.where((song) {
        final titleMatch = song.title.toLowerCase().contains(query);
        final artistMatch = song.artist.toLowerCase().contains(query);
        final tagsMatch = song.tags.any(
          (tag) => tag.toLowerCase().contains(query),
        );
        return titleMatch || artistMatch || tagsMatch;
      }).toList();
    }

    // Apply contributor filter
    if (_filterContributor != null) {
      filtered = filtered.where((song) {
        return song.contributedBy == _filterContributor;
      }).toList();
    }

    return filtered;
  }

  /// Get unique contributors from the songs.
  List<String> _getContributors(List<Song> songs) {
    final contributors = songs
        .where((s) => s.contributedBy != null)
        .map((s) => s.contributedBy!)
        .toSet()
        .toList();
    contributors.sort();
    return contributors;
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(bandSongsProvider(widget.band.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.band.name} Songs'),
        actions: [
          if (_filterContributor != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              onPressed: () {
                setState(() {
                  _filterContributor = null;
                });
              },
              tooltip: 'Clear filter',
            ),
        ],
      ),
      body: songsAsync.when(
        data: (songs) => _buildContent(context, ref, songs),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: _canEdit
          ? FloatingActionButton(
              onPressed: () => _addSongToBand(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, List<Song> songs) {
    final filteredSongs = _filterSongs(songs);
    final contributors = _getContributors(songs);

    return Column(
      children: [
        // Search and filter section
        _buildSearchAndFilter(context, contributors),
        // Songs list
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

  Widget _buildSearchAndFilter(
    BuildContext context,
    List<String> contributors,
  ) {
    return Column(
      children: [
        // Search field
        Padding(
          padding: const EdgeInsets.all(16),
          child: CustomTextField(
            hint: 'Search songs...',
            prefixIcon: Icons.search,
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        // Contributor filter chips
        if (contributors.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _filterContributor == null,
                  onSelected: (selected) {
                    setState(() {
                      _filterContributor = null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ...contributors.map(
                  (contributor) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(contributor),
                      selected: _filterContributor == contributor,
                      onSelected: (selected) {
                        setState(() {
                          _filterContributor = selected ? contributor : null;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (contributors.isNotEmpty) const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildEmptyState(bool isEmpty) {
    if (isEmpty) {
      return EmptyState(
        icon: Icons.music_note,
        message: 'No songs yet',
        hint: _canEdit
            ? 'Add songs to your band\'s collection'
            : 'No songs have been shared to this band yet',
        actionLabel: _canEdit ? 'Add Song' : null,
        onAction: _canEdit ? () => _addSongToBand(context, ref) : null,
      );
    }
    return EmptyState.search(query: _searchQuery);
  }

  Widget _buildSongCard(BuildContext context, WidgetRef ref, Song song) {
    return Dismissible(
      key: Key(song.id),
      direction: _canEdit ? DismissDirection.endToStart : DismissDirection.none,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (!_canEdit) return false;
        return await ConfirmationDialog.showDeleteDialog(
          context,
          title: 'Remove from Band',
          message: 'Are you sure you want to remove this song from the band?',
          confirmLabel: 'Remove',
        );
      },
      onDismissed: (direction) async {
        if (!_canEdit) return;
        final user = ref.read(currentUserProvider);
        if (user != null) {
          await ref
              .read(firestoreProvider)
              .deleteBandSong(widget.band.id, song.id);
        }
      },
      child: _buildSongTile(context, ref, song),
    );
  }

  Widget _buildSongTile(BuildContext context, WidgetRef ref, Song song) {
    final isCopy = song.isCopy;
    final contributorName = song.contributedBy;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCopy
              ? AppColors.color5.withValues(alpha: 0.3)
              : AppColors.color1.withValues(alpha: 0.3),
          child: Icon(
            isCopy ? Icons.content_copy : Icons.music_note,
            color: isCopy ? AppColors.color5 : AppColors.color1,
            size: 20,
          ),
        ),
        title: Text(song.title),
        subtitle: AttributionSubtitle(
          subtitle: song.artist,
          contributorName: contributorName,
          isCopy: isCopy,
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
            if (_canEdit)
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => _editSong(context, ref, song),
                tooltip: 'Edit',
              ),
          ],
        ),
        onTap: () => _editSong(context, ref, song),
      ),
    );
  }

  void _addSongToBand(BuildContext context, WidgetRef ref) {
    // Navigate to song picker or add new song
    // For now, we'll just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Song picker coming soon'),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }

  void _editSong(BuildContext context, WidgetRef ref, Song song) {
    if (!_canEdit) return;

    Navigator.pushNamed(context, '/edit-song', arguments: song);
  }
}

/// Provider for watching a band's songs.
final bandSongsProvider = StreamProvider.family<List<Song>, String>((
  ref,
  bandId,
) {
  return ref.watch(firestoreProvider).watchBandSongs(bandId);
});
