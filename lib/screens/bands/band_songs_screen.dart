import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/band.dart';
import '../../../models/song.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../providers/data/data_providers.dart';
import '../../../theme/mono_pulse_theme.dart';
import '../../../widgets/app_menu_sheet.dart';
import '../../../widgets/confirmation_dialog.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/menu_items_scope.dart';
import '../../../widgets/unified_item/adapters/song_item_adapter.dart';
import '../../../widgets/unified_item/song_card_actions.dart';
import '../../../widgets/unified_item/unified_item_list.dart';

/// Screen for displaying a band's shared songs.
///
/// This screen shows all songs that have been shared to the band's
/// song bank, with filtering by contributor and attribution badges.
class BandSongsScreen extends ConsumerStatefulWidget {
  const BandSongsScreen({required this.band, super.key});

  /// The band whose songs to display.
  final Band band;

  @override
  ConsumerState<BandSongsScreen> createState() => _BandSongsScreenState();
}

class _BandSongsScreenState extends ConsumerState<BandSongsScreen>
    with SongCardActions {
  String _searchQuery = '';
  String? _filterContributor;

  @override
  String get songActionsBandId => widget.band.id;

  /// Get the current user's role in the band.
  String? get _userRole {
    final user = ref.read(currentUserProvider).value;

    final member = widget.band.members.firstWhere(
      (m) => m.uid == user?.uid,
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

    // Pushed branch child: title + actions are published for the shell's
    // bottom bar ([← Back] [title] [⋮ Menu]); there is no top app bar. The
    // "clear filter" action (previously an AppBar icon) moved into the Menu
    // sheet.
    return MenuScopePublisher(
      data: MenuScopeData(
        title: '${widget.band.name} Songs',
        items: [
          if (_filterContributor != null)
            AppMenuItem(
              icon: Icons.filter_alt_off,
              label: 'Clear filter',
              onTap: () {
                setState(() {
                  _filterContributor = null;
                });
              },
            ),
        ],
      ),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: songsAsync.when(
            data: (songs) => _buildContent(context, ref, songs),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
        floatingActionButton: _canEdit
            ? FloatingActionButton(
                heroTag: 'band_songs_fab',
                onPressed: () => _addSongToBand(context, ref),
                child: const Icon(Icons.add),
              )
            : null,
      ),
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
                  items: [
                    for (final song in filteredSongs) SongItemAdapter(song),
                  ],
                  onEdit: _canEdit
                      ? (index) => _editSong(context, ref, filteredSongs[index])
                      : null,
                  onDelete: _canEdit
                      ? (index) => _removeFromBand(filteredSongs[index])
                      : null,
                  additionalActionsBuilder: (index) =>
                      buildSongActions(filteredSongs[index], bands: const []),
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
          padding: const EdgeInsets.all(MonoPulseSpacing.lg),
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
              padding: const EdgeInsets.symmetric(
                horizontal: MonoPulseSpacing.lg,
              ),
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
                    padding: const EdgeInsets.only(right: MonoPulseSpacing.sm),
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
            ? "Add songs to your band's collection"
            : 'No songs have been shared to this band yet',
        actionLabel: _canEdit ? 'Add Song' : null,
        onAction: _canEdit ? () => _addSongToBand(context, ref) : null,
      );
    }
    return EmptyState.search(query: _searchQuery);
  }

  Future<void> _removeFromBand(Song song) async {
    final confirmed = await ConfirmationDialog.showDeleteDialog(
      context,
      title: 'Remove from Band',
      message: 'Are you sure you want to remove this song from the band?',
      confirmLabel: 'Remove',
    );
    if (!confirmed) return;
    await ref.read(firestoreProvider).deleteBandSong(widget.band.id, song.id);
  }

  void _addSongToBand(BuildContext context, WidgetRef ref) {
    // Open the song form scoped to this band: the bandId makes the save target
    // saveBandSong instead of the user's personal library. Pushed, not go'd, so
    // saving pops back here instead of stranding the user in the Songs tab.
    context.pushNamed(
      'add-song',
      queryParameters: {'bandId': widget.band.id},
    );
  }

  void _editSong(BuildContext context, WidgetRef ref, Song song) {
    // Open the band copy's Song Page. bandId scopes the live stream and the
    // Edit tab's save target (updateBandSong, not the personal library); the
    // query parameter keeps that scope across a web refresh. Pushed, not
    // go'd, so Back returns here (band sub-routes are flat siblings).
    context.pushNamed(
      'song',
      pathParameters: {'id': song.id},
      queryParameters: {'bandId': widget.band.id},
      extra: {'song': song, 'bandId': widget.band.id},
    );
  }
}
