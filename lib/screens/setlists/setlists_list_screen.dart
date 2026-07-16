import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/setlist.dart';
import '../../models/song.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/data/metronome_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../services/export/pdf_service.dart';
import '../../services/export/setlist_export_sheet.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/snackbar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_banner.dart' show ErrorBanner, ErrorBannerStyle;
import '../../widgets/fab_variants.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/share_sheet.dart';
import '../../widgets/standard_screen_scaffold.dart';
import '../../widgets/unified_item/adapters/setlist_item_adapter.dart';
import '../../widgets/unified_item/unified_filter_sort_widget.dart';
import '../../widgets/unified_item/unified_item_list.dart';
import '../../widgets/unified_item/unified_item_model.dart';

class SetlistsListScreen extends ConsumerStatefulWidget {
  const SetlistsListScreen({super.key});

  @override
  ConsumerState<SetlistsListScreen> createState() => _SetlistsListScreenState();
}

class _SetlistsListScreenState extends ConsumerState<SetlistsListScreen> {
  String _searchQuery = '';
  SortOption _sortOption = SortOption.manual;
  List<Setlist>? _manualOrder; // Store manual order for manual sort mode

  List<SetlistItemAdapter> _filterAndSortSetlists(
      List<Setlist> setlists, List<Song>? songs) {
    // null while the songs stream is loading → adapter falls back to raw count
    final availableSongIds = songs?.map((s) => s.id).toSet();

    // Use manual order if in manual sort mode and we have it
    List<Setlist> setlistsToUse = setlists;
    if (_sortOption == SortOption.manual && _manualOrder != null) {
      setlistsToUse = _manualOrder!;
    }

    var adapters = setlistsToUse.map((setlist) {
      // Count only the songs that actually exist
      final resolvedCount = availableSongIds == null
          ? null
          : setlist.effectiveItems
              .where((item) => availableSongIds.contains(item.songId))
              .length;
      return SetlistItemAdapter(setlist, resolvedSongCount: resolvedCount);
    }).toList();

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      adapters = adapters.where((adapter) {
        return adapter.title.toLowerCase().contains(query) ||
            (adapter.subtitle?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Apply sorting (only for non-manual modes)
    if (_sortOption != SortOption.manual) {
      switch (_sortOption) {
        case SortOption.alphabetical:
          adapters.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );
        case SortOption.dateAdded:
          adapters.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        case SortOption.dateModified:
          adapters.sort(
            (a, b) => (b.updatedAt ?? DateTime(0)).compareTo(
              a.updatedAt ?? DateTime(0),
            ),
          );
        case SortOption.manual:
          break;
      }
    }

    return adapters;
  }

  void _handleReorder(int oldIndex, int newIndex) {
    // Update manual order when reordering (same pattern as songs)
    if (_manualOrder != null &&
        oldIndex >= 0 &&
        newIndex >= 0 &&
        oldIndex < _manualOrder!.length &&
        newIndex < _manualOrder!.length) {
      // Create a copy to avoid modifying the original list directly
      final newOrder = List<Setlist>.from(_manualOrder!);

      // Move item from oldIndex to newIndex
      final item = newOrder.removeAt(oldIndex);
      newOrder.insert(newIndex, item);

      setState(() {
        _manualOrder = newOrder;
      });

      // Save to Firestore
      _saveManualOrder(newOrder);
    }
  }

  Future<void> _saveManualOrder(List<Setlist> order) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    final service = ref.read(firestoreProvider);

    // Save all setlists with new order
    for (int i = 0; i < order.length; i++) {
      await service.saveSetlist(order[i], uid: user.uid);
    }
  }

  Future<void> _handleDelete(int index) async {
    final songs = ref.read(songsProvider).value;
    final adapters = _filterAndSortSetlists(
      ref.read(setlistsProvider).value ?? [],
      songs,
    );
    if (index >= adapters.length) return;
    final setlist = adapters[index].setlist;
    final user = ref.read(currentUserProvider).value;
    if (user != null) {
      await ref
          .read(firestoreProvider)
          .deleteSetlist(setlist.id, uid: user.uid);
    }
  }

  void _handleTap(int index) {
    final songs = ref.read(songsProvider).value;
    final adapters = _filterAndSortSetlists(
      ref.read(setlistsProvider).value ?? [],
      songs,
    );
    if (index >= adapters.length) return;
    // Open setlist for editing on tap
    _handleEdit(index);
  }

  void _handleEdit(int index) {
    final songs = ref.read(songsProvider).value;
    final adapters = _filterAndSortSetlists(
      ref.read(setlistsProvider).value ?? [],
      songs,
    );
    if (index >= adapters.length) return;
    final setlist = adapters[index].setlist;
    context.pushNamed(
      'edit-setlist',
      pathParameters: {'id': setlist.id},
      extra: setlist,
    );
  }

  @override
  Widget build(BuildContext context) {
    final setlistsAsync = ref.watch(setlistsProvider);
    final songsAsync = ref.watch(songsProvider);
    final canEdit = ref.watch(canEditProvider); // false for the shared demo account

    return StandardScreenScaffold(
      title: 'Setlists',
      showBackButton: false, // Hide back button for main tabs
      menuItems: [
        if (canEdit)
          PopupMenuItem<void>(
            child: const Text('Create Setlist'),
            onTap: () => context.goNamed('create-setlist'),
          ),
      ],
      floatingActionButton: canEdit
          ? SingleFab(
              icon: Icons.add,
              onPressed: () => context.goNamed('create-setlist'),
              heroTag: 'setlists_fab',
            )
          : null,
      body: _buildBody(setlistsAsync, songsAsync),
    );
  }

  Widget _buildBody(AsyncValue<List<Setlist>> setlistsAsync, AsyncValue<List<Song>> songsAsync) {
    return setlistsAsync.when(
      data: (setlists) => _buildContent(setlists, songsAsync),
      loading: () => const LoadingIndicator(),
      error: (e, _) => Center(
        child: ErrorBanner(
          message: e.toString(),
          onRetry: () => ref.invalidate(setlistsProvider),
          showRetry: true,
          style: ErrorBannerStyle.card,
        ),
      ),
    );
  }

  Widget _buildContent(List<Setlist> setlists, AsyncValue<List<Song>> songsAsync) {
    // Don't block setlists on the songs stream: while songs are loading the
    // adapter falls back to the raw songIds count.
    final filteredSetlists = _filterAndSortSetlists(setlists, songsAsync.value);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(MonoPulseSpacing.lg),
          child: UnifiedFilterSortWidget(
            currentSort: _sortOption,
            hintText: 'Search setlists...',
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
    if (isEmpty) {
      return EmptyState.setlists(
        onCreate: () => context.goNamed('create-setlist'),
      );
    }
    return EmptyState.search(query: _searchQuery);
  }

  Widget _buildSetlistList(List<SetlistItemAdapter> adapters) {
    final canEdit = ref.watch(canEditProvider); // demo account is read-only
    final canReorder = canEdit && _sortOption == SortOption.manual;
    return UnifiedItemList<SetlistItemAdapter>(
      items: adapters,
      enableReorder: canReorder,
      onReorder: canReorder ? _handleReorder : null,
      onDelete: canEdit ? _handleDelete : null,
      onTap: _handleTap,
      onEdit: canEdit ? _handleEdit : null,
      additionalActionsBuilder: (index) {
        final setlist = adapters[index].setlist;
        return [
          IconAction(
            icon: Icons.av_timer,
            tooltip: 'Open in metronome',
            color: MonoPulseColors.textSecondary,
            onPressed: () => _openInMetronome(setlist),
          ),
          OverflowMenuAction(
            entries: [
              ('Share', Icons.share, () => _shareSetlist(setlist)),
              ('Export PDF', Icons.picture_as_pdf, () => _exportPdf(setlist)),
            ],
          ),
        ];
      },
    );
  }

  /// Awaits the first emission instead of a one-shot `.value` read — a cold
  /// read on this screen resolved 0 songs → blank PDF/share/metronome (#80).
  Future<List<Song>> _songsForSetlist(Setlist setlist) async {
    final allSongs = await ref.read(songsProvider.future);
    return allSongs.where((s) => setlist.songIds.contains(s.id)).toList();
  }

  Future<void> _openInMetronome(Setlist setlist) async {
    final songs = await _songsForSetlist(setlist);
    if (!mounted) return;
    final loaded = ref
        .read(metronomeProvider.notifier)
        .loadSetlistQueue(setlist, availableSongs: songs);
    if (!loaded) {
      showAppSnackBar(
        context,
        'This setlist is empty or has unavailable songs.',
      );
      return;
    }
    await context.pushNamed('metronome');
  }

  Future<void> _shareSetlist(Setlist setlist) async {
    final songs = await _songsForSetlist(setlist);
    if (!mounted) return;
    _shareAsLinks(context, setlist, songs);
  }

  Future<void> _exportPdf(Setlist setlist) async {
    final layout = await pickSetlistPdfLayout(context);
    if (layout == null) return;
    final setlistSongs = await _songsForSetlist(setlist);
    try {
      await PdfService.exportSetlist(setlist, setlistSongs, layout: layout);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, 'Error: $e');
    }
  }

  void _shareAsLinks(BuildContext context, Setlist setlist, List<Song> songs) {
    final buffer = StringBuffer();
    buffer.writeln('🎵 ${setlist.name}');
    if (setlist.description != null) buffer.writeln(setlist.description);
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
    buffer.writeln('Created with FlowGroove');
    showShareSheet(context, buffer.toString(), subject: setlist.name);
  }
}
