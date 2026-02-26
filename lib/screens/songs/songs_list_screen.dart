import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/api_error.dart';
import '../../models/song.dart';
import '../../models/band.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/auth/error_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/offline_indicator.dart';
import '../../widgets/unified_item/unified_filter_sort_widget.dart';
import '../../widgets/unified_item/unified_item_list.dart';
import '../../widgets/unified_item/unified_item_model.dart';
import '../../widgets/unified_item/adapters/song_item_adapter.dart';
import 'components/csv_import_export/csv_import_export.dart';

/// Notifier for songs filter/sort state.
class SongsFilterSortNotifier extends Notifier<SongsFilterSortState> {
  @override
  SongsFilterSortState build() {
    return const SongsFilterSortState();
  }

  void setSortOption(SortOption option) {
    state = state.copyWith(sortOption: option);
  }

  void setFilterText(String text) {
    state = state.copyWith(filterText: text);
  }

  void setKeyFilter(String? key) {
    state = state.copyWith(keyFilter: key);
  }

  void setBpmFilter(int? bpm) {
    state = state.copyWith(bpmFilter: bpm);
  }

  void clearFilters() {
    state = const SongsFilterSortState();
  }
}

/// Provider for songs filter/sort state.
final songsFilterSortProvider =
    NotifierProvider<SongsFilterSortNotifier, SongsFilterSortState>(() {
      return SongsFilterSortNotifier();
    });

/// State class for songs filter/sort.
class SongsFilterSortState {
  final SortOption sortOption;
  final String filterText;
  final String? keyFilter;
  final int? bpmFilter;

  const SongsFilterSortState({
    this.sortOption = SortOption.alphabetical,
    this.filterText = '',
    this.keyFilter,
    this.bpmFilter,
  });

  SongsFilterSortState copyWith({
    SortOption? sortOption,
    String? filterText,
    String? keyFilter,
    int? bpmFilter,
  }) {
    return SongsFilterSortState(
      sortOption: sortOption ?? this.sortOption,
      filterText: filterText ?? this.filterText,
      keyFilter: keyFilter ?? this.keyFilter,
      bpmFilter: bpmFilter ?? this.bpmFilter,
    );
  }
}

/// Screen for displaying the list of songs with search, filter, and sort functionality.
class SongsListScreen extends ConsumerStatefulWidget {
  const SongsListScreen({super.key});

  @override
  ConsumerState<SongsListScreen> createState() => _SongsListScreenState();
}

class _SongsListScreenState extends ConsumerState<SongsListScreen> {
  ApiError? _currentError;
  final TextEditingController _filterController = TextEditingController();
  List<Song>? _manualOrder; // Store manual order for manual sort mode

  @override
  void initState() {
    super.initState();
    // Initialize filter controller with current filter text
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final state = ref.read(songsFilterSortProvider);
        _filterController.text = state.filterText;
      }
    });
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  /// Handle CSV import
  Future<void> _handleImport() async {
    final result = await showDialog<List<Song>>(
      context: context,
      builder: (_) => const SongImportDialog(),
    );

    if (result == null || result.isEmpty || !mounted) {
      return;
    }

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Text('Importing songs...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      // Get current user
      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: User not logged in'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Save each song to Firestore
      final firestore = FirestoreService();
      int savedCount = 0;
      int failedCount = 0;

      for (final song in result) {
        try {
          await firestore.saveSong(song, uid: user.uid);
          savedCount++;
        } catch (e) {
          debugPrint('Failed to save song "${song.title}": $e');
          failedCount++;
        }
      }

      if (!mounted) return;

      // Show success/error message
      if (savedCount > 0 && failedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported $savedCount song(s)'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (savedCount > 0 && failedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported $savedCount song(s), $failedCount failed'),
            backgroundColor: Colors.amber,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to import songs'),
            backgroundColor: Colors.red,
          ),
        );
      }

      // Refresh songs list
      ref.invalidate(songsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Handle CSV export
  Future<void> _handleExport(List<Song> songs) async {
    if (songs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No songs to export'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (_) => SongExportDialog(songs: songs),
    );
  }

  /// Filter and sort songs based on search query, key, BPM, and sort option.
  List<Song> _filterAndSortSongs(List<Song> songs) {
    final state = ref.read(songsFilterSortProvider);
    final searchQuery = state.filterText.trim().toLowerCase();
    final keyFilter = state.keyFilter;
    final bpmFilter = state.bpmFilter;
    final sortOption = state.sortOption;

    // Apply filters
    var filtered = songs.where((song) {
      // Search filter
      if (searchQuery.isNotEmpty) {
        final titleMatch = song.title.toLowerCase().contains(searchQuery);
        final artistMatch = song.artist.toLowerCase().contains(searchQuery);
        final tagsMatch = song.tags.any(
          (tag) => tag.toLowerCase().contains(searchQuery),
        );
        if (!titleMatch && !artistMatch && !tagsMatch) {
          return false;
        }
      }

      // Key filter
      if (keyFilter != null && song.ourKey != null) {
        if (song.ourKey!.toLowerCase() != keyFilter.toLowerCase()) {
          return false;
        }
      }

      // BPM filter
      if (bpmFilter != null && song.ourBPM != null) {
        if (song.ourBPM! != bpmFilter) {
          return false;
        }
      }

      return true;
    }).toList();

    // Apply sorting
    switch (sortOption) {
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
        // Manual sort - use stored manual order if available, otherwise maintain current order
        if (_manualOrder != null) {
          // Create a map for quick lookup
          final songMap = Map.fromEntries(
            _manualOrder!.map((song) => MapEntry(song.id, song)),
          );

          // Filter and reorder based on manual order
          filtered = filtered
              .where((song) => songMap.containsKey(song.id))
              .toList();
          filtered.sort(
            (a, b) =>
                _manualOrder!.indexOf(a).compareTo(_manualOrder!.indexOf(b)),
          );
        }
        break;
    }

    return filtered;
  }

  /// Clears the current error.
  void _clearError() {
    setState(() {
      _currentError = null;
    });
  }

  /// Handles an error from a stream.
  void _handleStreamError(Object error, StackTrace stackTrace) {
    final apiError = ApiError.fromException(error, stackTrace: stackTrace);
    setState(() {
      _currentError = apiError;
    });
    ref.read(errorNotifierProvider.notifier).handleError(apiError);
  }

  /// Show filter options bottom sheet.
  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final state = ref.read(songsFilterSortProvider);
          final currentKey = state.keyFilter;
          final currentBpm = state.bpmFilter;

          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter Options',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Key filter
                const Text(
                  'Key',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: currentKey == null,
                      onSelected: (_) {
                        ref
                            .read(songsFilterSortProvider.notifier)
                            .setKeyFilter(null);
                        setModalState(() {});
                      },
                    ),
                    ...[
                      'C',
                      'C#',
                      'D',
                      'D#',
                      'E',
                      'F',
                      'F#',
                      'G',
                      'G#',
                      'A',
                      'A#',
                      'B',
                    ].map(
                      (key) => FilterChip(
                        label: Text(key),
                        selected: currentKey == key,
                        onSelected: (_) {
                          ref
                              .read(songsFilterSortProvider.notifier)
                              .setKeyFilter(key);
                          setModalState(() {});
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // BPM filter
                const Text(
                  'BPM',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<int?>(
                        isExpanded: true,
                        value: currentBpm,
                        hint: const Text('Any BPM'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Any BPM'),
                          ),
                          ...[60, 80, 100, 120, 140, 160, 180].map(
                            (bpm) => DropdownMenuItem(
                              value: bpm,
                              child: Text('$bpm BPM'),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          ref
                              .read(songsFilterSortProvider.notifier)
                              .setBpmFilter(value);
                          setModalState(() {});
                        },
                      ),
                    ),
                    if (currentBpm != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          ref
                              .read(songsFilterSortProvider.notifier)
                              .setBpmFilter(null);
                          setModalState(() {});
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Clear all filters button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      ref.read(songsFilterSortProvider.notifier).clearFilters();
                      Navigator.pop(context);
                    },
                    child: const Text('Clear All Filters'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songsProvider);
    final bandsAsync = ref.watch(bandsProvider);

    return Scaffold(
      appBar: CustomAppBar.build(
        context,
        title: 'Songs',
        menuItems: [
          PopupMenuItem<void>(
            child: const Text('Import from CSV'),
            onTap: _handleImport,
          ),
          PopupMenuItem<void>(
            child: const Text('Export to CSV'),
            onTap: songsAsync.value != null && songsAsync.value!.isNotEmpty
                ? () => _handleExport(songsAsync.value!)
                : null,
          ),
        ],
      ),
      body: Column(
        children: [
          OfflineIndicator.banner(),
          Expanded(child: _buildBody(songsAsync, bandsAsync)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'songs_fab',
        onPressed: () => context.goNamed('add-song'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(
    AsyncValue<List<Song>> songsAsync,
    AsyncValue<List<Band>> bandsAsync,
  ) {
    return songsAsync.when(
      data: (songs) {
        // Clear error when data loads successfully
        if (_currentError != null) {
          _clearError();
        }
        return _buildContent(context, ref, songs, bandsAsync);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, stack) {
        _handleStreamError(e, stack);
        return _buildErrorState();
      },
    );
  }

  Widget _buildErrorState() {
    if (_currentError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorBanner.card(
            message: _currentError?.message ?? 'An unexpected error occurred',
            onRetry: () {
              _clearError();
              // Trigger a refresh by re-watching the provider
              ref.invalidate(songsProvider);
            },
          ),
        ),
      );
    }
    return const Center(child: Text('An error occurred'));
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<Song> songs,
    AsyncValue<List<Band>> bandsAsync,
  ) {
    final filteredSongs = _filterAndSortSongs(songs);
    final bands = bandsAsync.value ?? [];
    final state = ref.watch(songsFilterSortProvider);

    // Initialize manual order when entering manual sort mode for the first time
    if (state.sortOption == SortOption.manual && _manualOrder == null) {
      setState(() {
        _manualOrder = List<Song>.from(filteredSongs);
      });
    }

    // Convert songs to adapters with callbacks
    final songAdapters = filteredSongs.map((song) {
      return SongItemAdapter(
        song,
        onEdit: () => _navigateToEdit(song),
        onDelete: () => _deleteSong(song),
        onTap: () => _navigateToEdit(song),
      );
    }).toList();

    return Column(
      children: [
        // Inline error banner if there's an error but we have cached data
        if (_currentError != null && filteredSongs.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: ErrorBanner.inline(
              message: _currentError?.message ?? 'An unexpected error occurred',
              onRetry: () {
                _clearError();
                ref.invalidate(songsProvider);
              },
            ),
          ),
        ],

        // Unified filter/sort widget
        Padding(
          padding: const EdgeInsets.all(16),
          child: UnifiedFilterSortWidget(
            currentSort: state.sortOption,
            onSortChanged: (option) {
              if (option != null) {
                ref
                    .read(songsFilterSortProvider.notifier)
                    .setSortOption(option);

                // Reset manual order when switching away from manual sort
                if (option != SortOption.manual && _manualOrder != null) {
                  setState(() {
                    _manualOrder = null;
                  });
                }
              }
            },
            filterText: state.filterText,
            onFilterChanged: (value) {
              ref
                  .read(songsFilterSortProvider.notifier)
                  .setFilterText(value ?? '');
              _filterController.text = value ?? '';
            },
          ),
        ),

        // Filter indicators
        if (state.keyFilter != null || state.bpmFilter != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (state.keyFilter != null)
                  Chip(
                    label: Text('Key: ${state.keyFilter}'),
                    onDeleted: () {
                      ref
                          .read(songsFilterSortProvider.notifier)
                          .setKeyFilter(null);
                    },
                    deleteIcon: const Icon(Icons.close, size: 18),
                  ),
                if (state.bpmFilter != null) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('BPM: ${state.bpmFilter}'),
                    onDeleted: () {
                      ref
                          .read(songsFilterSortProvider.notifier)
                          .setBpmFilter(null);
                    },
                    deleteIcon: const Icon(Icons.close, size: 18),
                  ),
                ],
                const Spacer(),
                TextButton(
                  onPressed: () {
                    ref.read(songsFilterSortProvider.notifier).clearFilters();
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),

        // Filter button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text(
                'Filters:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _showFilterOptions,
                icon: const Icon(Icons.filter_list, size: 18),
                label: const Text('Key / BPM'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${filteredSongs.length} ${filteredSongs.length == 1 ? 'song' : 'songs'}',
                style: const TextStyle(
                  color: MonoPulseColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: filteredSongs.isEmpty
              ? _buildEmptyState(songs.isEmpty)
              : _buildSongList(
                  songAdapters,
                  bands,
                  state.sortOption == SortOption.manual,
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isEmpty) {
    if (isEmpty) {
      return EmptyState.songs(onAdd: () => context.goNamed('add-song'));
    }
    return EmptyState.search(
      query: ref.read(songsFilterSortProvider).filterText,
    );
  }

  Widget _buildSongList(
    List<SongItemAdapter> songAdapters,
    List<Band> bands,
    bool enableReorder,
  ) {
    return UnifiedItemList<SongItemAdapter>(
      items: songAdapters,
      enableReorder: enableReorder,
      onReorder: _handleReorder,
      onDelete: (index) => _deleteSongByIndex(index),
      onEdit: (index) => _navigateToEditByIndex(index),
      additionalActionsBuilder: bands.isNotEmpty
          ? (index) => [_buildAddToBandAction(songAdapters[index], bands)]
          : null,
    );
  }

  /// Build "Add to Band" action for the trailing actions.
  UnifiedItemAction _buildAddToBandAction(
    SongItemAdapter adapter,
    List<Band> bands,
  ) {
    return _AddToBandAction(
      adapter: adapter,
      bands: bands,
      context: context,
      ref: ref,
      onAddToBand: _addToBand,
    );
  }

  /// Navigate to edit song screen.
  void _navigateToEdit(Song song) {
    context.pushNamed(
      'edit-song',
      pathParameters: {'id': song.id},
      extra: song,
    );
  }

  /// Navigate to edit song screen by index.
  void _navigateToEditByIndex(int index) {
    final songs = ref.read(songsProvider).value ?? [];
    final filteredSongs = _filterAndSortSongs(songs);
    if (index >= 0 && index < filteredSongs.length) {
      _navigateToEdit(filteredSongs[index]);
    }
  }

  /// Delete song with confirmation.
  Future<void> _deleteSong(Song song) async {
    final confirmed = await ConfirmationDialog.showDeleteDialog(
      context,
      title: 'Delete Song',
      message: 'Are you sure you want to delete "${song.title}"?',
      confirmLabel: 'Delete',
    );

    if (!confirmed) return;

    final userAsync = ref.read(currentUserProvider);
    final user = userAsync.value;
    if (user == null) return;

    try {
      await ref.read(songRepositoryProvider).deleteSong(song.id, uid: user.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Song deleted'),
          backgroundColor: Colors.green,
        ),
      );
    } on ApiError catch (e) {
      _handleStreamError(e, StackTrace.current);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e, stackTrace) {
      final error = ApiError.fromException(e, stackTrace: stackTrace);
      _handleStreamError(error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  /// Delete song by index.
  void _deleteSongByIndex(int index) {
    final songs = ref.read(songsProvider).value ?? [];
    final filteredSongs = _filterAndSortSongs(songs);
    if (index >= 0 && index < filteredSongs.length) {
      _deleteSong(filteredSongs[index]);
    }
  }

  /// Handle reordering of songs in manual sort mode.
  void _handleReorder(int oldIndex, int newIndex) {
    // Update manual order when reordering
    if (_manualOrder != null &&
        oldIndex >= 0 &&
        newIndex >= 0 &&
        oldIndex < _manualOrder!.length &&
        newIndex < _manualOrder!.length) {
      // Create a copy to avoid modifying the original list directly
      final newOrder = List<Song>.from(_manualOrder!);

      // Move item from oldIndex to newIndex
      final item = newOrder.removeAt(oldIndex);
      newOrder.insert(newIndex, item);

      setState(() {
        _manualOrder = newOrder;
      });
    }
  }

  /// Add a song to a band.
  Future<void> _addToBand(Song song, String bandId) async {
    final userAsync = ref.read(currentUserProvider);
    final user = userAsync.value;
    if (user == null) return;

    try {
      await ref
          .read(songRepositoryProvider)
          .addSongToBand(
            song: song,
            bandId: bandId,
            contributorId: user.uid,
            contributorName: user.displayName ?? user.email ?? 'Unknown',
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${song.title}" to band'),
          backgroundColor: Colors.green,
        ),
      );
    } on ApiError catch (e) {
      _handleStreamError(e, StackTrace.current);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e, stackTrace) {
      final error = ApiError.fromException(e, stackTrace: stackTrace);
      _handleStreamError(error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

/// Custom action for "Add to Band" functionality.
class _AddToBandAction implements UnifiedItemAction {
  final SongItemAdapter adapter;
  final List<Band> bands;
  final BuildContext context;
  final WidgetRef ref;
  final Future<void> Function(Song, String) onAddToBand;

  _AddToBandAction({
    required this.adapter,
    required this.bands,
    required this.context,
    required this.ref,
    required this.onAddToBand,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.add_to_queue, size: 20),
      tooltip: 'Add to Band',
      onSelected: (bandId) async {
        await onAddToBand(adapter.song, bandId);
      },
      itemBuilder: (context) => [
        ...bands.map(
          (band) => PopupMenuItem<String>(
            value: band.id,
            child: Row(
              children: [
                const Icon(Icons.groups, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(band.name, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
