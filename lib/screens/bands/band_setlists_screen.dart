import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/band.dart';
import '../../models/setlist.dart';
import '../../models/song.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/permissions_provider.dart';
import '../../services/export/pdf_service.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/fab_variants.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/standard_screen_scaffold.dart';
import '../../widgets/unified_item/adapters/setlist_item_adapter.dart';
import '../../widgets/unified_item/unified_filter_sort_widget.dart';
import '../../widgets/unified_item/unified_item_list.dart';
import '../../widgets/unified_item/unified_item_model.dart';
import '../setlists/create_setlist_screen.dart';

class BandSetlistsScreen extends ConsumerStatefulWidget {
  const BandSetlistsScreen({required this.band, super.key});

  final Band band;

  @override
  ConsumerState<BandSetlistsScreen> createState() => _BandSetlistsScreenState();
}

class _BandSetlistsScreenState extends ConsumerState<BandSetlistsScreen> {
  String _searchQuery = '';
  SortOption _sortOption = SortOption.manual;
  List<Setlist>? _manualOrder;

  bool get _canEdit {
    if (ref.read(isDemoUserProvider)) return false;
    final user = ref.read(currentUserProvider).value;
    if (user == null) return false;
    final member = widget.band.members.firstWhere(
      (m) => m.uid == user.uid,
      orElse: () => BandMember(uid: '', role: ''),
    );
    return member.role == BandMember.roleAdmin ||
        member.role == BandMember.roleEditor;
  }

  bool get _canDelete {
    if (ref.read(isDemoUserProvider)) return false;
    final user = ref.read(currentUserProvider).value;
    if (user == null) return false;
    final member = widget.band.members.firstWhere(
      (m) => m.uid == user.uid,
      orElse: () => BandMember(uid: '', role: ''),
    );
    return member.role == BandMember.roleAdmin;
  }

  List<SetlistItemAdapter> _filterAndSortSetlists(List<Setlist> setlists) {
    List<Setlist> setlistsToUse = setlists;
    if (_sortOption == SortOption.manual && _manualOrder != null) {
      setlistsToUse = _manualOrder!;
    }

    var adapters = setlistsToUse
        .map((setlist) => SetlistItemAdapter(setlist))
        .toList();

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      adapters = adapters.where((adapter) {
        return adapter.title.toLowerCase().contains(query) ||
            (adapter.subtitle?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    if (_sortOption != SortOption.manual) {
      switch (_sortOption) {
        case SortOption.alphabetical:
          adapters.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );
          break;
        case SortOption.dateAdded:
          adapters.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
        case SortOption.dateModified:
          adapters.sort(
            (a, b) => (b.updatedAt ?? DateTime(0)).compareTo(
              a.updatedAt ?? DateTime(0),
            ),
          );
          break;
        case SortOption.manual:
          break;
      }
    }

    return adapters;
  }

  void _handleCreate() {
    context.goNamed(
      'create-setlist',
      queryParameters: {
        'bandId': widget.band.id,
        'scope': SetlistStorageScope.band.name,
      },
    );
  }

  void _handleReorder(int oldIndex, int newIndex) {
    if (!_canEdit ||
        _manualOrder == null ||
        oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= _manualOrder!.length ||
        newIndex >= _manualOrder!.length) {
      return;
    }

    final newOrder = List<Setlist>.from(_manualOrder!);
    final item = newOrder.removeAt(oldIndex);
    newOrder.insert(newIndex, item);

    setState(() {
      _manualOrder = newOrder;
    });

    _saveManualOrder(newOrder);
  }

  Future<void> _saveManualOrder(List<Setlist> order) async {
    if (!_canEdit) return;
    final service = ref.read(firestoreProvider);
    for (final setlist in order) {
      await service.saveBandSetlist(setlist, widget.band.id);
    }
  }

  Future<void> _deleteSetlist(Setlist setlist) async {
    if (!_canDelete) return;
    await ref
        .read(firestoreProvider)
        .deleteBandSetlist(widget.band.id, setlist.id);
  }

  void _editSetlist(Setlist setlist) {
    if (!_canEdit) return;
    context.pushNamed(
      'edit-setlist',
      pathParameters: {'id': setlist.id},
      queryParameters: {
        'bandId': widget.band.id,
        'scope': SetlistStorageScope.band.name,
      },
      extra: setlist,
    );
  }

  @override
  Widget build(BuildContext context) {
    final setlistsAsync = ref.watch(bandSetlistsProvider(widget.band.id));
    final canEdit = _canEdit;

    return StandardScreenScaffold(
      title: '${widget.band.name} Setlists',
      menuItems: canEdit
          ? [
              PopupMenuItem<void>(
                child: const Text('Create Band Setlist'),
                onTap: _handleCreate,
              ),
            ]
          : null,
      floatingActionButton: canEdit
          ? SingleFab(
              icon: Icons.add,
              onPressed: _handleCreate,
              heroTag: 'band_setlists_fab_${widget.band.id}',
            )
          : null,
      body: _buildBody(setlistsAsync),
    );
  }

  Widget _buildBody(AsyncValue<List<Setlist>> setlistsAsync) {
    return setlistsAsync.when(
      data: (setlists) => _buildContent(setlists),
      loading: () => const LoadingIndicator(),
      error: (e, _) => Center(
        child: ErrorBanner.card(
          message: e.toString(),
          onRetry: () => ref.invalidate(bandSetlistsProvider(widget.band.id)),
        ),
      ),
    );
  }

  Widget _buildContent(List<Setlist> setlists) {
    final filteredSetlists = _filterAndSortSetlists(setlists);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(MonoPulseSpacing.lg),
          child: UnifiedFilterSortWidget(
            currentSort: _sortOption,
            hintText: 'Search band setlists...',
            onSortChanged: (option) {
              if (option != null) setState(() => _sortOption = option);
            },
            filterText: _searchQuery.isEmpty ? null : _searchQuery,
            onFilterChanged: (value) =>
                setState(() => _searchQuery = value ?? ''),
          ),
        ),
        Expanded(
          child: filteredSetlists.isEmpty
              ? _buildEmptyState(setlists.isEmpty)
              : _buildSetlistList(filteredSetlists),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isEmpty) {
    if (!isEmpty) {
      return EmptyState.search(query: _searchQuery);
    }

    return EmptyState(
      icon: Icons.playlist_play,
      message: 'No band setlists yet',
      hint: _canEdit
          ? 'Create a shared setlist for this band'
          : 'Shared setlists will appear here',
      actionLabel: _canEdit ? 'Create Band Setlist' : null,
      onAction: _canEdit ? _handleCreate : null,
    );
  }

  Widget _buildSetlistList(List<SetlistItemAdapter> adapters) {
    return UnifiedItemList<SetlistItemAdapter>(
      items: adapters,
      enableReorder: _canEdit && _sortOption == SortOption.manual,
      onReorder: _canEdit && _sortOption == SortOption.manual
          ? _handleReorder
          : null,
      onDelete: _canDelete
          ? (index) => _deleteSetlist(adapters[index].setlist)
          : null,
      onTap: null,
      onEdit: _canEdit
          ? (index) => _editSetlist(adapters[index].setlist)
          : null,
      showCompact: false,
      additionalActionsBuilder: (index) {
        final setlist = adapters[index].setlist;
        return [
          if (_canEdit)
            _SetlistIconAction(
              icon: Icons.edit,
              tooltip: 'Edit setlist',
              color: MonoPulseColors.textSecondary,
              onPressed: () => _editSetlist(setlist),
            ),
          _SetlistIconAction(
            icon: Icons.link,
            tooltip: 'Copy links',
            color: MonoPulseColors.textSecondary,
            onPressed: () => _shareAsLinks(setlist),
          ),
          _SetlistIconAction(
            icon: Icons.picture_as_pdf,
            tooltip: 'Export PDF',
            color: MonoPulseColors.error,
            onPressed: () => _exportPdf(setlist),
          ),
        ];
      },
    );
  }

  List<Song> _songsForSetlist(Setlist setlist) {
    final allSongs = ref.read(bandSongsProvider(widget.band.id)).value ?? [];
    final songsById = {for (final song in allSongs) song.id: song};
    return setlist.songIds
        .map((songId) => songsById[songId])
        .whereType<Song>()
        .toList();
  }

  Future<void> _exportPdf(Setlist setlist) async {
    try {
      await PdfService.exportSetlist(setlist, _songsForSetlist(setlist));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _shareAsLinks(Setlist setlist) {
    final songs = _songsForSetlist(setlist);
    final buffer = StringBuffer();
    buffer.writeln(setlist.name);
    if (setlist.description != null) buffer.writeln(setlist.description);
    buffer.writeln();
    buffer.writeln('Songs:');
    for (int i = 0; i < songs.length; i++) {
      final song = songs[i];
      buffer.writeln('${i + 1}. ${song.title} - ${song.artist}');
      if (song.spotifyUrl != null) {
        buffer.writeln('   ${song.spotifyUrl}');
      } else {
        final searchUrl = Uri.encodeComponent('${song.title} ${song.artist}');
        buffer.writeln('   https://open.spotify.com/search/$searchUrl');
      }
    }
    buffer.writeln();
    buffer.writeln('Created with FlowGroove');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Setlist links copied to clipboard!')),
    );
  }
}

class _SetlistIconAction implements UnifiedItemAction {
  _SetlistIconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20, color: color),
      onPressed: onPressed,
      tooltip: tooltip,
    );
  }
}
