import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/setlist.dart';
import '../../models/song.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/data/metronome_provider.dart';
import '../../services/export/pdf_service.dart';
import '../../services/export/setlist_export_sheet.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_banner.dart' show ErrorBanner, ErrorBannerStyle;
import '../../widgets/fab_variants.dart';
import '../../widgets/loading_indicator.dart';
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

  List<SetlistItemAdapter> _filterAndSortSetlists(List<Setlist> setlists) {
    // Use manual order if in manual sort mode and we have it
    List<Setlist> setlistsToUse = setlists;
    if (_sortOption == SortOption.manual && _manualOrder != null) {
      setlistsToUse = _manualOrder!;
    }

    var adapters = setlistsToUse
        .map(SetlistItemAdapter.new)
        .toList();

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
    final adapters = _filterAndSortSetlists(
      ref.read(setlistsProvider).value ?? [],
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
    final adapters = _filterAndSortSetlists(
      ref.read(setlistsProvider).value ?? [],
    );
    if (index >= adapters.length) return;
    // Open setlist for editing on tap
    _handleEdit(index);
  }

  void _handleEdit(int index) {
    final adapters = _filterAndSortSetlists(
      ref.read(setlistsProvider).value ?? [],
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

    return StandardScreenScaffold(
      title: 'Setlists',
      showBackButton: false, // Hide back button for main tabs
      menuItems: [
        PopupMenuItem<void>(
          child: const Text('Create Setlist'),
          onTap: () => context.goNamed('create-setlist'),
        ),
      ],
      floatingActionButton: SingleFab(
        icon: Icons.add,
        onPressed: () => context.goNamed('create-setlist'),
        heroTag: 'setlists_fab',
      ),
      body: _buildBody(setlistsAsync),
    );
  }

  Widget _buildBody(AsyncValue<List<Setlist>> setlistsAsync) {
    return setlistsAsync.when(
      data: _buildContent,
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

  Widget _buildContent(List<Setlist> setlists) {
    final filteredSetlists = _filterAndSortSetlists(setlists);

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
    return UnifiedItemList<SetlistItemAdapter>(
      items: adapters,
      enableReorder: _sortOption == SortOption.manual,
      onReorder: _sortOption == SortOption.manual ? _handleReorder : null,
      onDelete: _handleDelete,
      onTap: _handleTap,
      onEdit: _handleEdit,
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
              ('Copy links', Icons.link, () => _copyLinks(setlist)),
              ('Export PDF', Icons.picture_as_pdf, () => _exportPdf(setlist)),
            ],
          ),
        ];
      },
    );
  }

  List<Song> _songsForSetlist(Setlist setlist) {
    final allSongs = ref.read(songsProvider).value ?? [];
    return allSongs.where((s) => setlist.songIds.contains(s.id)).toList();
  }

  void _openInMetronome(Setlist setlist) {
    final loaded = ref
        .read(metronomeProvider.notifier)
        .loadSetlistQueue(setlist, availableSongs: _songsForSetlist(setlist));
    if (!loaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This setlist is empty or has unavailable songs.')),
      );
      return;
    }
    context.goNamed('metronome');
  }

  void _copyLinks(Setlist setlist) {
    _shareAsLinks(context, setlist, _songsForSetlist(setlist));
  }

  Future<void> _exportPdf(Setlist setlist) async {
    final layout = await pickSetlistPdfLayout(context);
    if (layout == null) return;
    final setlistSongs = _songsForSetlist(setlist);
    try {
      await PdfService.exportSetlist(setlist, setlistSongs, layout: layout);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Setlist links copied to clipboard!')),
    );
  }
}
