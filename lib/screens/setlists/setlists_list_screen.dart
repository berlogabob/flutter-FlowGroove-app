import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/auth/auth_provider.dart';
import '../../models/setlist.dart';
import '../../models/song.dart';
import '../../services/export/pdf_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/offline_indicator.dart';
import '../../widgets/unified_item/unified_item_list.dart';
import '../../widgets/unified_item/unified_filter_sort_widget.dart';
import '../../widgets/unified_item/adapters/setlist_item_adapter.dart';
import '../../widgets/unified_item/unified_item_model.dart';
import '../../widgets/empty_state.dart';

class SetlistsListScreen extends ConsumerStatefulWidget {
  const SetlistsListScreen({super.key});

  @override
  ConsumerState<SetlistsListScreen> createState() => _SetlistsListScreenState();
}

class _SetlistsListScreenState extends ConsumerState<SetlistsListScreen> {
  String _searchQuery = '';
  SortOption _sortOption = SortOption.manual;

  List<SetlistItemAdapter> _filterAndSortSetlists(List<Setlist> setlists) {
    var adapters = setlists
        .map((setlist) => SetlistItemAdapter(setlist))
        .toList();

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      adapters = adapters.where((adapter) {
        return adapter.title.toLowerCase().contains(query) ||
            (adapter.subtitle?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    switch (_sortOption) {
      case SortOption.manual:
        break;
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
    }

    return adapters;
  }

  void _handleReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final setlists = ref.read(setlistsProvider).value;
    if (setlists == null) return;
    final setlist = setlists.removeAt(oldIndex);
    setlists.insert(newIndex, setlist);
    final service = ref.read(firestoreProvider);
    final user = ref.read(currentUserProvider).value;
    if (user != null) {
      for (int i = 0; i < setlists.length; i++) {
        await service.saveSetlist(setlists[i], uid: user.uid);
      }
    }
  }

  void _handleDelete(int index) async {
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
    _showExportOptions(context, ref, adapters[index].setlist);
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

    return Scaffold(
      appBar: CustomAppBar.build(
        context,
        title: 'Setlists',
        menuItems: [
          PopupMenuItem<void>(
            child: const Text('Create Setlist'),
            onTap: () => context.goNamed('create-setlist'),
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineIndicator.banner(),
          Expanded(child: _buildBody(setlistsAsync)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'setlists_fab',
        onPressed: () => context.goNamed('create-setlist'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(AsyncValue<List<Setlist>> setlistsAsync) {
    return setlistsAsync.when(
      data: (setlists) => _buildContent(setlists),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildContent(List<Setlist> setlists) {
    final filteredSetlists = _filterAndSortSetlists(setlists);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: UnifiedFilterSortWidget(
            currentSort: _sortOption,
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
      showCompact: false,
      additionalActionsBuilder: (index) {
        return [
          _PdfExportAction(
            onPressed: () => _exportPdf(adapters[index].setlist),
          ),
        ];
      },
    );
  }

  void _exportPdf(Setlist setlist) async {
    final songsAsync = ref.read(songsProvider);
    final allSongs = songsAsync.value ?? [];
    final setlistSongs = allSongs
        .where((s) => setlist.songIds.contains(s.id))
        .toList();
    try {
      await PdfService.exportSetlist(setlist, setlistSongs);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
    buffer.writeln('Created with RepSync');
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Setlist links copied to clipboard!')),
    );
  }
}

class _PdfExportAction implements UnifiedItemAction {
  final VoidCallback? onPressed;
  _PdfExportAction({this.onPressed});
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.picture_as_pdf, size: 20, color: Colors.red),
      onPressed: onPressed,
      tooltip: 'Export PDF',
    );
  }
}
