import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/api_error.dart';
import '../../models/song.dart';
import '../../models/song_import_plan.dart';
import '../../models/tuner_launch_context.dart';
import '../../models/band.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/data/metronome_provider.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/auth/error_provider.dart';
import '../../services/song_library_merge_service.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../widgets/standard_screen_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/unified_item/adapters/song_item_adapter.dart';
import '../../widgets/unified_item/unified_item_list.dart';
import '../../widgets/unified_item/unified_item_model.dart';
import '../../widgets/unified_item/unified_filter_sort_widget.dart';
import '../../widgets/tag_cloud_widget.dart';
import '../../widgets/fab_variants.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/app_filter_chip.dart';
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

  void setTagFilter(String? tag) {
    if (tag == null) {
      state = state.copyWith(clearTagFilter: true);
    } else {
      state = state.copyWith(tagFilter: tag);
    }
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
  final String? tagFilter;

  const SongsFilterSortState({
    this.sortOption = SortOption.alphabetical,
    this.filterText = '',
    this.keyFilter,
    this.bpmFilter,
    this.tagFilter,
  });

  SongsFilterSortState copyWith({
    SortOption? sortOption,
    String? filterText,
    String? keyFilter,
    int? bpmFilter,
    String? tagFilter,
    bool clearTagFilter = false,
  }) {
    return SongsFilterSortState(
      sortOption: sortOption ?? this.sortOption,
      filterText: filterText ?? this.filterText,
      keyFilter: keyFilter ?? this.keyFilter,
      bpmFilter: bpmFilter ?? this.bpmFilter,
      tagFilter: clearTagFilter ? null : (tagFilter ?? this.tagFilter),
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
  Map<String, int> _tagCloud = {};
  final bool _loadingTagCloud = false;

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
    final currentSongs = ref.read(songsProvider).value ?? const <Song>[];
    final result = await showDialog<SongImportAnalysis>(
      context: context,
      builder: (_) => SongImportDialog(librarySongs: currentSongs),
    );

    if (result == null || !result.hasWork || !mounted) {
      return;
    }

    final totalOperations = result.songsToCreate.length + result.updates.length;
    final completedOperations = ValueNotifier<int>(0);
    var progressDialogOpen = true;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Importing songs'),
            content: ValueListenableBuilder<int>(
              valueListenable: completedOperations,
              builder: (context, completed, _) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: totalOperations == 0
                        ? 1
                        : completed / totalOperations,
                  ),
                  const SizedBox(height: 12),
                  Text('$completed of $totalOperations changes completed'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    void closeProgress() {
      if (!progressDialogOpen || !mounted) return;
      progressDialogOpen = false;
      Navigator.of(context, rootNavigator: true).pop();
      Future<void>.delayed(
        const Duration(milliseconds: 300),
        completedOperations.dispose,
      );
    }

    try {
      // Get current user
      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user == null) {
        if (!mounted) return;
        closeProgress();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: User not logged in'),
            backgroundColor: MonoPulseColors.error,
          ),
        );
        return;
      }

      // Save each song through the repository so linked canonical songs use
      // the v2 LibrarySong write path.
      final songRepo = ref.read(songRepositoryProvider);
      int addedCount = 0;
      int mergedCount = 0;
      final failures = <String>[];
      final warnings = <String>[];

      for (final song in result.songsToCreate) {
        try {
          await songRepo.saveSong(song, uid: user.uid);
          addedCount++;
        } catch (e) {
          debugPrint('Failed to save song "${song.title}": $e');
          failures.add('${song.title}: $e');
        } finally {
          completedOperations.value++;
        }
      }

      final mergeService = SongLibraryMergeService(
        firestore: ref.read(firebaseFirestoreProvider),
      );
      for (final update in result.updates) {
        try {
          final warning = await mergeService.mergeImportedSong(
            uid: user.uid,
            original: update.original,
            merged: update.merged,
            sources: update.sources,
            songRepository: songRepo,
          );
          mergedCount += update.sources.length;
          if (warning != null) warnings.add(warning);
        } catch (e) {
          debugPrint('Failed to merge imported song: $e');
          failures.add('${update.merged.title}: $e');
        } finally {
          completedOperations.value++;
        }
      }

      if (!mounted) return;
      closeProgress();

      // Show success/error message
      final completedCount = addedCount + mergedCount;
      if (completedCount > 0 && failures.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              warnings.isEmpty
                  ? 'Imported $addedCount new, merged $mergedCount'
                  : 'Imported $addedCount new, merged $mergedCount. ${warnings.length} history warning(s)',
            ),
            backgroundColor: warnings.isEmpty
                ? MonoPulseColors.success
                : MonoPulseColors.warning,
          ),
        );
      } else if (completedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported $completedCount row(s), ${failures.length} operation(s) failed',
            ),
            backgroundColor: MonoPulseColors.warning,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to import songs'),
            backgroundColor: MonoPulseColors.error,
          ),
        );
      }

      // Refresh songs list
      ref.invalidate(songsProvider);
    } catch (e) {
      if (!mounted) return;
      closeProgress();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import error: $e'),
          backgroundColor: MonoPulseColors.error,
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
          backgroundColor: MonoPulseColors.warning,
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (_) => SongExportDialog(songs: songs),
    );
  }

  void _runAfterPopupClose(Future<void> Function() action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(action());
    });
  }

  /// Filter and sort songs based on search query, key, BPM, tag, and sort option.
  List<Song> _filterAndSortSongs(List<Song> songs) {
    final state = ref.read(songsFilterSortProvider);
    final searchQuery = state.filterText.trim().toLowerCase();
    final keyFilter = state.keyFilter;
    final bpmFilter = state.bpmFilter;
    final tagFilter = state.tagFilter;
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

      // Tag filter
      if (tagFilter != null && tagFilter.isNotEmpty) {
        final hasTag = song.tags.any(
          (tag) => tag.toLowerCase() == tagFilter.toLowerCase(),
        );
        if (!hasTag) {
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
    ref.read(errorStateProvider.notifier).handleError(apiError);
  }

  /// Show filter options bottom sheet.
  void _showFilterOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final state = ref.read(songsFilterSortProvider);
          final currentKey = state.keyFilter;
          final currentBpm = state.bpmFilter;

          return Container(
            padding: const EdgeInsets.all(MonoPulseSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filter Options',
                  style: MonoPulseTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
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
                    AppFilterChip(
                      label: 'All',
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
                      (key) => AppFilterChip(
                        label: key,
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
    final exportSongs = songsAsync.value;
    final canExport = exportSongs != null && exportSongs.isNotEmpty;

    return StandardScreenScaffold(
      title: 'Songs',
      showBackButton: false, // Hide back button for main tabs
      menuItems: [
        PopupMenuItem<void>(
          enabled: canExport,
          onTap: canExport
              ? () => _runAfterPopupClose(
                  () async => context.pushNamed('song-duplicates'),
                )
              : null,
          child: const Text('Find duplicates'),
        ),
        PopupMenuItem<void>(
          onTap: () => _runAfterPopupClose(_handleImport),
          child: const Text('Import from CSV'),
        ),
        PopupMenuItem<void>(
          enabled: canExport,
          onTap: canExport
              ? () => _runAfterPopupClose(
                  () => _handleExport(List<Song>.from(exportSongs)),
                )
              : null,
          child: const Text('Export to CSV'),
        ),
      ],
      floatingActionButton: SingleFab(
        icon: Icons.add,
        onPressed: () => context.goNamed('add-song'),
        heroTag: 'songs_fab',
      ),
      body: _buildBody(songsAsync, bandsAsync),
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
      loading: () => const LoadingIndicator(),
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
          padding: const EdgeInsets.all(MonoPulseSpacing.xxl),
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
            padding: const EdgeInsets.all(MonoPulseSpacing.lg),
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
          padding: const EdgeInsets.all(MonoPulseSpacing.lg),
          child: UnifiedFilterSortWidget(
            currentSort: state.sortOption,
            hintText: 'Search songs...',
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
            padding: const EdgeInsets.symmetric(
              horizontal: MonoPulseSpacing.lg,
            ),
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

        // Tag cloud filter
        if (songs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MonoPulseSpacing.lg,
              vertical: 8,
            ),
            child: _buildTagCloud(songs),
          ),

        // Filter button
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MonoPulseSpacing.lg,
            vertical: 8,
          ),
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
                    horizontal: MonoPulseSpacing.md,
                    vertical: 8,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${filteredSongs.length} ${filteredSongs.length == 1 ? 'song' : 'songs'}',
                style: MonoPulseTypography.bodySmall.copyWith(
                  color: MonoPulseColors.textSecondary,
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

  Widget _buildTagCloud(List<Song> songs) {
    // Build tag cloud from songs if not loaded
    if (_tagCloud.isEmpty && !_loadingTagCloud && songs.isNotEmpty) {
      _buildTagCloudFromSongs(songs);
    }

    if (_tagCloud.isEmpty) {
      return const SizedBox.shrink();
    }

    final state = ref.watch(songsFilterSortProvider);

    return TagCloudWidget(
      tagCounts: _tagCloud,
      selectedTag: state.tagFilter,
      onTagSelected: (tag) {
        ref.read(songsFilterSortProvider.notifier).setTagFilter(tag);
      },
    );
  }

  void _buildTagCloudFromSongs(List<Song> songs) {
    final tagCounts = <String, int>{};
    for (final song in songs) {
      for (final tag in song.tags) {
        final tagLower = tag.toLowerCase();
        tagCounts[tagLower] = (tagCounts[tagLower] ?? 0) + 1;
      }
    }
    // Sort by count descending
    final sortedTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    setState(() {
      _tagCloud = Map.fromEntries(sortedTags.take(20));
    });
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
      additionalActionsBuilder: (index) =>
          _buildSongActions(songAdapters[index], bands),
    );
  }

  List<UnifiedItemAction> _buildSongActions(
    SongItemAdapter adapter,
    List<Band> bands,
  ) {
    return [
      _OpenInTunerAction(onPressed: () => _openInTuner(adapter.song)),
      if (_hasMetronomeData(adapter.song))
        _OpenInMetronomeAction(onPressed: () => _openInMetronome(adapter.song)),
      if (bands.isNotEmpty) _buildAddToBandAction(adapter, bands),
    ];
  }

  bool _hasMetronomeData(Song song) {
    return song.ourBPM != null ||
        song.originalBPM != null ||
        song.accentBeats != 4 ||
        song.regularBeats != 1 ||
        song.beatModes.isNotEmpty;
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

  void _openInMetronome(Song song) {
    final metronome = ref.read(metronomeProvider.notifier);
    if (ref.read(metronomeProvider).isPlaying) {
      metronome.stop();
    }
    metronome.loadSongTempo(song);
    context.goNamed('metronome');
  }

  void _openInTuner(Song song) {
    final user = ref.read(currentUserProvider).value;
    unawaited(
      context.pushNamed<void>(
        'tuner',
        extra: TunerLaunchContext(
          song: song,
          saveSong: user == null
              ? null
              : (updatedSong) async {
                  await ref
                      .read(songRepositoryProvider)
                      .saveSong(updatedSong, uid: user.uid);
                  ref.invalidate(songsProvider);
                },
        ),
      ),
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
          backgroundColor: MonoPulseColors.success,
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
          backgroundColor: MonoPulseColors.success,
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

class _OpenInMetronomeAction implements UnifiedItemAction {
  const _OpenInMetronomeAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('open-in-metronome-action'),
      icon: const Icon(Icons.speed, size: 20),
      color: MonoPulseColors.accentOrange,
      tooltip: 'Open in Metronome',
      onPressed: onPressed,
    );
  }
}

class _OpenInTunerAction implements UnifiedItemAction {
  const _OpenInTunerAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('open-in-tuner-action'),
      icon: const Icon(Icons.tune, size: 20),
      color: MonoPulseColors.accentOrange,
      tooltip: 'Open in Tuner',
      onPressed: onPressed,
    );
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
