import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/song.dart';
import '../../../models/band.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../providers/data/data_providers.dart';
import '../../../theme/mono_pulse_theme.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/confirmation_dialog.dart';
import '../../../widgets/custom_app_bar.dart';
import '../../../widgets/unified_item/unified_item_list.dart';
import '../../../widgets/unified_item/unified_item_model.dart';
import '../../../widgets/unified_item/adapters/song_item_adapter.dart';
import '../../../widgets/unified_item/unified_filter_sort_widget.dart';
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
  SortOption _sortOption = SortOption.alphabetical;
  bool _isTagsExpanded = false;
  bool _isMembersExpanded = false;

  final List<String> _availableTags = [
    'rock',
    'pop',
    'jazz',
    'blues',
    'metal',
    'folk',
    'country',
    'reggae',
    'funk',
    'r&b',
    'cover band',
    'original',
    'tribute',
    'wedding',
    'bar',
    'live',
    'studio',
  ];

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

    // Apply sorting
    switch (_sortOption) {
      case SortOption.alphabetical:
        filtered.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case SortOption.dateAdded:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.dateModified:
        filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case SortOption.manual:
        // Keep current order for manual
        break;
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
      appBar: CustomAppBar.build(
        context,
        title: widget.band.name,
        menuItems: [
          PopupMenuItem<void>(
            onTap: () => _showAboutBand(context),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 20),
                SizedBox(width: 12),
                Text('About Band'),
              ],
            ),
          ),
          PopupMenuItem<void>(
            onTap: () => _showMembers(context),
            child: const Row(
              children: [
                Icon(Icons.people_outline, size: 20),
                SizedBox(width: 12),
                Text('Members'),
              ],
            ),
          ),
          PopupMenuItem<void>(
            onTap: () => _shareBand(context),
            child: const Row(
              children: [
                Icon(Icons.share_outlined, size: 20),
                SizedBox(width: 12),
                Text('Share Band'),
              ],
            ),
          ),
          PopupMenuItem<void>(
            onTap: () => _editDescription(context),
            child: const Row(
              children: [
                Icon(Icons.edit_outlined, size: 20),
                SizedBox(width: 12),
                Text('Edit Description'),
              ],
            ),
          ),
          if (_filterContributor != null)
            PopupMenuItem<void>(
              onTap: () {
                setState(() {
                  _filterContributor = null;
                });
              },
              child: const Row(
                children: [
                  Icon(Icons.filter_alt_off, size: 20),
                  SizedBox(width: 12),
                  Text('Clear Filter'),
                ],
              ),
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
        // Band Info Header
        _buildBandHeader(),
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
                  enableReorder: _sortOption == SortOption.manual,
                  onReorder: _sortOption == SortOption.manual
                      ? (oldIndex, newIndex) =>
                            _handleReorder(oldIndex, newIndex, filteredSongs)
                      : null,
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
                  onTap: (index) =>
                      _editSong(context, ref, filteredSongs[index]),
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

  Widget _buildBandHeader() {
    final band = widget.band;
    final description = band.description;

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description section (replaces "Ready to rock?")
          if (description != null && description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                description,
                style: const TextStyle(
                  color: MonoPulseColors.textSecondary,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Ready to rock',
                style: TextStyle(
                  color: MonoPulseColors.textTertiary,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          // Quick Actions - Tags and Members (collapsible)
          Card(
            child: Column(
              children: [
                // Tags section
                InkWell(
                  onTap: () =>
                      setState(() => _isTagsExpanded = !_isTagsExpanded),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.label_outline, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Tags',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        Text(
                          '${band.tags.length}',
                          style: const TextStyle(
                            color: MonoPulseColors.textSecondary,
                          ),
                        ),
                        AnimatedRotation(
                          turns: _isTagsExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(Icons.keyboard_arrow_down),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isTagsExpanded)
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableTags.map((tag) {
                        final isSelected = band.tags.contains(tag);
                        return FilterChip(
                          label: Text(tag),
                          selected: isSelected,
                          onSelected: _canEdit
                              ? (selected) => _toggleTag(tag, selected)
                              : null,
                          selectedColor: MonoPulseColors.accentOrangeSubtle,
                          checkmarkColor: MonoPulseColors.accentOrange,
                        );
                      }).toList(),
                    ),
                  ),

                if (_isTagsExpanded && _isMembersExpanded)
                  const Divider(height: 1),

                // Members section
                InkWell(
                  onTap: () =>
                      setState(() => _isMembersExpanded = !_isMembersExpanded),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.people_outline, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Members',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        Text(
                          '${band.members.length}',
                          style: const TextStyle(
                            color: MonoPulseColors.textSecondary,
                          ),
                        ),
                        AnimatedRotation(
                          turns: _isMembersExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(Icons.keyboard_arrow_down),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isMembersExpanded)
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      children: band.members.map((member) {
                        return _buildMemberTile(member);
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleTag(String tag, bool selected) async {
    final currentTags = List<String>.from(widget.band.tags);
    if (selected) {
      currentTags.add(tag);
    } else {
      currentTags.remove(tag);
    }

    final updatedBand = widget.band.copyWith(tags: currentTags);

    try {
      final userAsync = ref.read(currentUserProvider);
      final user = userAsync.value;
      if (user == null) return;

      await ref.read(firestoreProvider).saveBand(updatedBand, uid: user.uid);
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating tags: $e')));
      }
    }
  }

  Widget _buildSearchAndFilter(
    BuildContext context,
    List<String> contributors,
  ) {
    return Column(
      children: [
        // Unified filter/sort widget at top (like personal songs bank)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: UnifiedFilterSortWidget(
            currentSort: _sortOption,
            onSortChanged: (option) {
              if (option != null) {
                setState(() => _sortOption = option);
              }
            },
            filterText: _searchQuery,
            onFilterChanged: (value) {
              setState(() => _searchQuery = value ?? '');
            },
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

    context.pushNamed(
      'edit-song',
      pathParameters: {'id': song.id},
      extra: {'song': song, 'bandId': widget.band.id},
    );
  }

  void _handleReorder(int oldIndex, int newIndex, List<Song> songs) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = songs.removeAt(oldIndex);
      songs.insert(newIndex, item);
    });
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

    final userAsync = ref.read(currentUserProvider);
    final user = userAsync.value;
    if (user != null) {
      await ref.read(firestoreProvider).deleteBandSong(widget.band.id, song.id);
    }
  }

  void _showAboutBand(BuildContext context) {
    context.pushNamed(
      'band-about',
      pathParameters: {'id': widget.band.id},
      extra: widget.band,
    );
  }

  void _showMembers(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MonoPulseColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.25,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) =>
            _buildMembersSheet(context, scrollController),
      ),
    );
  }

  Widget _buildMembersSheet(
    BuildContext context,
    ScrollController scrollController,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ListView(
        controller: scrollController,
        children: [
          Text(
            'Band Members',
            style: MonoPulseTypography.headlineLarge.copyWith(
              color: MonoPulseColors.textHighEmphasis,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (widget.band.members.isEmpty)
            const Text('No members found')
          else
            ...widget.band.members.map(
              (member) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: MonoPulseColors.accentOrange,
                  child: Text(
                    (member.displayName ?? member.email ?? '?')[0]
                        .toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(member.displayName ?? member.email ?? 'Unknown'),
                subtitle: Text(_formatRole(member.role)),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _shareBand(BuildContext context) async {
    final inviteCode = widget.band.inviteCode;
    if (inviteCode == null || inviteCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No invite code available for this band')),
      );
      return;
    }

    // Use Firebase hosting URL (you can configure custom domain in Firebase Console)
    const String domain = 'repsync-app-8685c.web.app';

    final shareText =
        'Join my band "${widget.band.name}" on RepSync!\n\n'
        'Use invite code: $inviteCode\n\n'
        'Or click the link: https://$domain/join-band?code=$inviteCode';

    await SharePlus.instance.share(
      ShareParams(
        text: shareText,
        subject: 'Join my band "${widget.band.name}" on RepSync',
      ),
    );
  }

  void _editDescription(BuildContext context) {
    final controller = TextEditingController(text: widget.band.description);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MonoPulseColors.surface,
        title: const Text('Edit Description'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter band description...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final userAsync = ref.read(currentUserProvider);
              final user = userAsync.value;
              if (user != null) {
                await ref
                    .read(firestoreProvider)
                    .saveBand(
                      widget.band.copyWith(description: controller.text),
                      uid: user.uid,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Description updated')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(BandMember member) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: MonoPulseColors.accentOrange,
                  radius: 20,
                  child: Text(
                    (member.displayName ?? member.email ?? '?')[0]
                        .toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.displayName ?? member.email ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      // Permission role badge
                      Row(
                        children: [
                          _buildPermissionBadge(member.role),
                          const SizedBox(width: 8),
                          if (_canEdit && member.uid != _currentUserId)
                            GestureDetector(
                              onTap: () => _showEditMemberDialog(member),
                              child: const Icon(
                                Icons.edit,
                                size: 16,
                                color: MonoPulseColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Music roles display
            if (member.musicRoles.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: member.musicRoles.map((role) {
                  return Chip(
                    label: Text(role, style: const TextStyle(fontSize: 10)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: MonoPulseColors.accentOrangeSubtle,
                    labelStyle: const TextStyle(
                      color: MonoPulseColors.accentOrange,
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionBadge(String role) {
    Color color;
    String icon;
    switch (role) {
      case 'admin':
        color = Colors.red;
        icon = 'A';
        break;
      case 'editor':
        color = Colors.blue;
        icon = 'E';
        break;
      default:
        color = Colors.grey;
        icon = 'V';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon == 'A'
                ? Icons.star
                : icon == 'E'
                ? Icons.edit
                : Icons.visibility,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            icon,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String? get _currentUserId {
    final userAsync = ref.read(currentUserProvider);
    return userAsync.value?.uid;
  }

  void _showEditMemberDialog(BandMember member) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MonoPulseColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _EditMemberSheet(
        member: member,
        band: widget.band,
        onSave: (updatedMember) => _updateMember(updatedMember),
      ),
    );
  }

  Future<void> _updateMember(BandMember updatedMember) async {
    final currentMembers = List<BandMember>.from(widget.band.members);
    final index = currentMembers.indexWhere((m) => m.uid == updatedMember.uid);
    if (index != -1) {
      currentMembers[index] = updatedMember;
      final updatedBand = widget.band.copyWith(members: currentMembers);

      try {
        final userAsync = ref.read(currentUserProvider);
        final user = userAsync.value;
        if (user == null) return;

        await ref.read(firestoreProvider).saveBand(updatedBand, uid: user.uid);
        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error updating member: $e')));
        }
      }
    }
  }

  String _formatRole(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'editor':
        return 'Editor';
      case 'viewer':
      default:
        return 'Viewer';
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

class _EditMemberSheet extends StatefulWidget {
  final BandMember member;
  final Band band;
  final Function(BandMember) onSave;

  const _EditMemberSheet({
    required this.member,
    required this.band,
    required this.onSave,
  });

  @override
  State<_EditMemberSheet> createState() => _EditMemberSheetState();
}

class _EditMemberSheetState extends State<_EditMemberSheet> {
  late List<String> _selectedMusicRoles;
  late String _selectedPermission;

  static const List<String> musicRoles = [
    'Vocal',
    'Guitar',
    'Bass',
    'Drums',
    'Keyboard',
    'Piano',
    'Saxophone',
    'Trumpet',
    'Violin',
    'Cello',
    'DJ',
    'Harmonica',
    'Banjo',
    'Ukulele',
    'Percussion',
    'Backing Vocal',
    'Loop Station',
  ];

  static const List<String> workingRoles = [
    'Band Manager',
    'Sound Engineer',
    'Lighting',
    'Booking Agent',
    'Producer',
    'Songwriter',
    'Arranger',
    'Booking',
    'Merch',
    'Social Media',
    'Photographer',
    'Videographer',
  ];

  @override
  void initState() {
    super.initState();
    _selectedMusicRoles = List<String>.from(widget.member.musicRoles);
    _selectedPermission = widget.member.role;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit Member',
                    style: MonoPulseTypography.headlineLarge.copyWith(
                      color: MonoPulseColors.textHighEmphasis,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Member name
              Text(
                widget.member.displayName ?? widget.member.email ?? 'Unknown',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),

              // Permission role section
              const Text(
                'Permission Role',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: MonoPulseColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildPermissionChip('admin', 'Admin', Colors.red),
                  _buildPermissionChip('editor', 'Editor', Colors.blue),
                  _buildPermissionChip('viewer', 'Viewer', Colors.grey),
                ],
              ),
              const SizedBox(height: 24),

              // Music roles section
              const Text(
                'Music Roles',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: MonoPulseColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: musicRoles.map((role) {
                  final isSelected = _selectedMusicRoles.contains(role);
                  return FilterChip(
                    label: Text(role),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedMusicRoles.add(role);
                        } else {
                          _selectedMusicRoles.remove(role);
                        }
                      });
                    },
                    selectedColor: MonoPulseColors.accentOrangeSubtle,
                    checkmarkColor: MonoPulseColors.accentOrange,
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Working roles section
              const Text(
                'Working Roles',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: MonoPulseColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: workingRoles.map((role) {
                  final isSelected = _selectedMusicRoles.contains(role);
                  return FilterChip(
                    label: Text(role),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedMusicRoles.add(role);
                        } else {
                          _selectedMusicRoles.remove(role);
                        }
                      });
                    },
                    selectedColor: MonoPulseColors.accentOrangeSubtle,
                    checkmarkColor: MonoPulseColors.accentOrange,
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // Save button
              ElevatedButton(
                onPressed: () {
                  final updatedMember = widget.member.copyWith(
                    role: _selectedPermission,
                    musicRoles: _selectedMusicRoles,
                  );
                  widget.onSave(updatedMember);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: MonoPulseColors.accentOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save Changes'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPermissionChip(String value, String label, Color color) {
    final isSelected = _selectedPermission == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedPermission = value);
        }
      },
      selectedColor: color.withValues(alpha: 0.3),
      labelStyle: TextStyle(
        color: isSelected ? color : MonoPulseColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
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
