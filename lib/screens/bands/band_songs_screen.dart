import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/song.dart';
import '../../../models/band.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../providers/data/data_providers.dart';
import '../../../theme/mono_pulse_theme.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../widgets/confirmation_dialog.dart';
import '../../../widgets/unified_item/unified_item_list.dart';
import '../../../widgets/unified_item/unified_item_model.dart';
import '../../../widgets/unified_item/adapters/song_item_adapter.dart';
import 'song_picker_screen.dart';

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
    final userAsync = ref.read(currentUserProvider);
    final user = userAsync.value;
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
              heroTag: 'band_songs_fab',
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
              : UnifiedItemList<SongItemAdapter>(
                  items: filteredSongs.map((song) {
                    return SongItemAdapter(
                      song,
                      onEdit: () => _editSong(context, ref, song),
                      onDelete: () => _deleteSongFromBand(context, ref, song),
                      onTap: () => _editSong(context, ref, song),
                    );
                  }).toList(),
                  enableReorder: false,
                  onReorder: null,
                  onDelete: _canEdit
                      ? (index) => _deleteSongFromBand(
                            context,
                            ref,
                            filteredSongs[index],
                          )
                      : null,
                  onEdit: _canEdit
                      ? (index) => _editSong(context, ref, filteredSongs[index])
                      : null,
                  onTap: (index) => _editSong(context, ref, filteredSongs[index]),
                  additionalActionsBuilder: _canEdit
                      ? (index) => [
                          _BuildEditAction(
                            context: context,
                            ref: ref,
                            song: filteredSongs[index],
                            onEdit: () =>
                                _editSong(context, ref, filteredSongs[index]),
                          ),
                        ]
                      : null,
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

  void _addSongToBand(BuildContext context, WidgetRef ref) async {
    // Navigate to song picker to select from personal library
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SongPickerScreen(band: widget.band),
      ),
    );

    // Refresh songs if songs were added
    if (result == true && mounted) {
      ref.invalidate(bandSongsProvider(widget.band.id));
    }
  }

  void _editSong(BuildContext context, WidgetRef ref, Song song) {
    if (!_canEdit) return;

    context.pushNamed('edit-song', pathParameters: {'id': song.id}, extra: song);
  }

  Future<void> _deleteSongFromBand(
    BuildContext context,
    WidgetRef ref,
    Song song,
  ) async {
    if (!_canEdit) return;

    final confirmed = await ConfirmationDialog.showDeleteDialog(
      context,
      title: 'Remove from Band',
      message: 'Are you sure you want to remove this song from the band?',
      confirmLabel: 'Remove',
    );

    if (!confirmed) return;

    final user = ref.read(currentUserProvider);
    if (user != null) {
      await ref.read(firestoreProvider).deleteBandSong(widget.band.id, song.id);
    }
  }
}

/// Custom action for edit functionality in band songs screen
class _BuildEditAction implements UnifiedItemAction {
  final BuildContext context;
  final WidgetRef ref;
  final Song song;
  final VoidCallback onEdit;

  _BuildEditAction({
    required this.context,
    required this.ref,
    required this.song,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(
        Icons.edit,
        size: 20,
        color: MonoPulseColors.textSecondary,
      ),
      onPressed: onEdit,
      tooltip: 'Edit',
    );
  }
}

/// Provider for watching a band's songs.
final bandSongsProvider = StreamProvider.family<List<Song>, String>((
  ref,
  bandId,
) {
  return ref.watch(firestoreProvider).watchBandSongs(bandId);
});
