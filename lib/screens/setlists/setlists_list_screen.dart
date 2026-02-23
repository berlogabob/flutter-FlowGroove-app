import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/auth/auth_provider.dart';
import '../../models/setlist.dart';
import '../../models/song.dart';
import '../../services/export/pdf_service.dart';
import '../../widgets/unified_item/unified_item_card.dart';
import '../../widgets/unified_item/unified_filter_sort_widget.dart';
import '../../widgets/unified_item/adapters/setlist_item_adapter.dart';
import '../../widgets/unified_item/unified_item_model.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/offline_indicator.dart';

/// Screen for displaying the list of setlists with search, filter, sort,
/// swipe-to-delete, and drag-and-drop reordering.
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
  SortOption _sortOption = SortOption.manual;

  /// Filter and sort setlists based on search query and sort option.
  List<SetlistItemAdapter> _filterAndSortSetlists(List<Setlist> setlists) {
    // Convert setlists to adapters
    var adapters = setlists
        .map((setlist) => SetlistItemAdapter(setlist))
        .toList();

    // Apply search filter
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      adapters = adapters.where((adapter) {
        return adapter.title.toLowerCase().contains(query) ||
            (adapter.subtitle?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Apply sorting
    switch (_sortOption) {
      case SortOption.manual:
        // Keep original order (user can reorder via drag-and-drop)
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
        adapters.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
    }

    return adapters;
  }

  /// Handle setlist reordering (manual sort mode).
  void _handleReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final setlists = ref.read(setlistsProvider).value;
    if (setlists == null) return;

    // Perform the reordering locally first
    final setlist = setlists.removeAt(oldIndex);
    setlists.insert(newIndex, setlist);

    // Save the reordered setlists to Firestore (fire-and-forget)
    final service = ref.read(firestoreProvider);
    final user = ref.read(currentUserProvider);
    if (user != null) {
      for (int i = 0; i < setlists.length; i++) {
        service.saveSetlist(setlists[i], user.uid);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final setlistsAsync = ref.watch(setlistsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setlists'),
        actions: const [OfflineStatusIcon()],
      ),
      body: Column(
        children: [
          const OfflineIndicator(),
          Expanded(child: _buildBody(setlistsAsync)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'setlists_fab',
        onPressed: () => Navigator.pushNamed(context, '/setlists/create'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(AsyncValue<List<Setlist>> setlistsAsync) {
    return setlistsAsync.when(
      data: (setlists) => _buildContent(context, ref, setlists),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<Setlist> setlists,
  ) {
    final filteredSetlists = _filterAndSortSetlists(setlists);

    return Column(
      children: [
        // Unified filter/sort widget
        Padding(
          padding: const EdgeInsets.all(16),
          child: UnifiedFilterSortWidget(
            currentSort: _sortOption,
            onSortChanged: (option) => setState(() => _sortOption = option),
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
        onCreate: () => Navigator.pushNamed(context, '/setlists/create'),
      );
    }
    return EmptyState.search(query: _searchQuery);
  }

  Widget _buildSetlistList(List<SetlistItemAdapter> adapters) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: adapters.length,
      onReorder: _sortOption == SortOption.manual
          ? _handleReorder
          : (oldIndex, newIndex) {}, // No-op when not in manual mode
      proxyDecorator: (child, index, animation) {
        return Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final adapter = adapters[index];
        final setlist = adapter.setlist;

        return Dismissible(
          key: ValueKey(setlist.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.delete_outline,
              color: Colors.red.shade700,
              size: 28,
            ),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart) {
              return await _confirmDelete(context, ref, setlist);
            }
            return false;
          },
          onDismissed: (direction) {
            if (direction == DismissDirection.endToStart) {
              // Deletion is handled in confirmDismiss
            }
          },
          child: UnifiedItemCard<SetlistItemAdapter>(
            item: adapter,
            onTap: () => _showExportOptions(context, ref, setlist),
            onEdit: () => Navigator.pushNamed(
              context,
              '/setlists/${setlist.id}/edit',
              arguments: setlist,
            ),
            // onDelete is handled by swipe-to-delete
            onDelete: () => _confirmDelete(context, ref, setlist),
            showCompact: false,
            customActions: [
              _PdfExportAction(
                onPressed: () => _exportPdf(context, ref, setlist),
              ),
            ],
          ),
        );
      },
    );
  }

  void _exportPdf(BuildContext context, WidgetRef ref, Setlist setlist) async {
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

  Future<bool> _confirmDelete(
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

    return confirmed;
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

/// Custom action for PDF export in the unified item card.
class _PdfExportAction implements UnifiedItemAction {
  final VoidCallback? onPressed;

  _PdfExportAction({this.onPressed});

  @override
  Widget build() {
    return IconButton(
      icon: const Icon(Icons.picture_as_pdf, size: 20, color: Colors.red),
      onPressed: onPressed,
      tooltip: 'Export PDF',
    );
  }
}
