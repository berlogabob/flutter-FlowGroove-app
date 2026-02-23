import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/api_error.dart';
import '../../models/song.dart';
import '../../models/band.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/auth/error_provider.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/offline_indicator.dart';
import '../../widgets/unified_item/unified_filter_sort_widget.dart';

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
        // Manual sort - maintain current order (user can drag to reorder)
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
      appBar: AppBar(
        title: const Text('Songs'),
        actions: const [OfflineStatusIcon()],
      ),
      body: Column(
        children: [
          const OfflineIndicator(),
          Expanded(child: _buildBody(songsAsync, bandsAsync)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'songs_fab',
        onPressed: () => Navigator.pushNamed(context, '/songs/add'),
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
          child: ErrorBanner(
            message: _currentError!.message,
            title: _currentError!.title,
            onRetry: () {
              _clearError();
              // Trigger a refresh by re-watching the provider
              ref.invalidate(songsProvider);
            },
            showRetry: _currentError!.isNetwork,
            style: ErrorBannerStyle.card,
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

    return Column(
      children: [
        // Inline error banner if there's an error but we have cached data
        if (_currentError != null && filteredSongs.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: ErrorBanner(
              message: _currentError!.message,
              title: _currentError!.title,
              onRetry: () {
                _clearError();
                ref.invalidate(songsProvider);
              },
              showRetry: _currentError!.isNetwork,
              style: ErrorBannerStyle.inline,
            ),
          ),
        ],

        // Unified filter/sort widget
        Padding(
          padding: const EdgeInsets.all(16),
          child: UnifiedFilterSortWidget(
            currentSort: state.sortOption,
            onSortChanged: (option) {
              ref.read(songsFilterSortProvider.notifier).setSortOption(option);
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
                  filteredSongs,
                  bands,
                  state.sortOption == SortOption.manual,
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isEmpty) {
    if (isEmpty) {
      return EmptyState.songs(
        onAdd: () => Navigator.pushNamed(context, '/songs/add'),
      );
    }
    return EmptyState.search(
      query: ref.read(songsFilterSortProvider).filterText,
    );
  }

  Widget _buildSongList(
    List<Song> songs,
    List<Band> bands,
    bool enableReorder,
  ) {
    return ReorderableListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: songs.length,
      onReorder: (oldIndex, newIndex) {
        if (enableReorder) {
          _handleReorder(oldIndex, newIndex);
        }
      },
      itemBuilder: (context, index) {
        final song = songs[index];
        final isShared = song.isCopy || song.bandId != null;

        return Dismissible(
          key: Key('dismiss-${song.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            return await ConfirmationDialog.showDeleteDialog(
              context,
              title: 'Delete Song',
              message: 'Are you sure you want to delete this song?',
              confirmLabel: 'Delete',
            );
          },
          onDismissed: (direction) async {
            final user = ref.read(currentUserProvider);
            if (user != null) {
              try {
                await ref.read(firestoreProvider).deleteSong(song.id, user.uid);
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
          },
          child: Card(
            key: Key('card-${song.id}'),
            margin: const EdgeInsets.symmetric(
              horizontal: MonoPulseSpacing.lg,
              vertical: MonoPulseSpacing.sm,
            ),
            child: InkWell(
              onTap: () => Navigator.pushNamed(
                context,
                '/songs/${song.id}/edit',
                arguments: song,
              ),
              onLongPress: bands.isNotEmpty
                  ? () => _showAddToBandMenu(context, ref, song, bands)
                  : null,
              child: ListTile(
                leading: ReorderableDragStartListener(
                  enabled: enableReorder,
                  index: index,
                  child: CircleAvatar(
                    backgroundColor: isShared
                        ? MonoPulseColors.accentOrangeSubtle
                        : MonoPulseColors.accentOrangeSubtle,
                    child: Icon(
                      isShared ? Icons.content_copy : Icons.music_note,
                      color: isShared
                          ? MonoPulseColors.accentOrange
                          : MonoPulseColors.accentOrange,
                      size: 20,
                    ),
                  ),
                ),
                title: Text(
                  song.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: MonoPulseColors.textPrimary,
                    decoration: isShared
                        ? TextDecoration.underline
                        : TextDecoration.none,
                    decorationColor: MonoPulseColors.accentOrange,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.artist,
                      style: const TextStyle(
                        color: MonoPulseColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (song.ourKey != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: MonoPulseColors.accentOrangeSubtle,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              song.ourKey!,
                              style: const TextStyle(
                                color: MonoPulseColors.accentOrange,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        if (song.ourBPM != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: MonoPulseColors.accentOrangeSubtle,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${song.ourBPM} BPM',
                              style: const TextStyle(
                                color: MonoPulseColors.accentOrange,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (song.spotifyUrl != null)
                      IconButton(
                        icon: const Icon(
                          Icons.play_circle_fill,
                          color: Colors.green,
                          size: 28,
                        ),
                        onPressed: () async {
                          final uri = Uri.parse(song.spotifyUrl!);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        tooltip: 'Play on Spotify',
                      ),
                    if (bands.isNotEmpty)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.add_to_queue, size: 20),
                        tooltip: 'Add to Band',
                        onSelected: (bandId) =>
                            _addToBand(context, ref, song, bandId),
                        itemBuilder: (context) => [
                          ...bands.map(
                            (band) => PopupMenuItem<String>(
                              value: band.id,
                              child: Row(
                                children: [
                                  const Icon(Icons.groups, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      band.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (enableReorder)
                      const Icon(
                        Icons.drag_handle,
                        color: MonoPulseColors.textTertiary,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Handle reordering of songs in manual sort mode.
  void _handleReorder(int oldIndex, int newIndex) {
    // Note: This only updates the local UI order.
    // To persist the order, you would need to update the backend.
    // For now, this provides visual reordering capability.
    setState(() {
      // The ReorderableListView handles the visual reordering
    });
  }

  /// Show a menu to select a band for adding the song.
  void _showAddToBandMenu(
    BuildContext context,
    WidgetRef ref,
    Song song,
    List<Band> bands,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add to Band',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${song.title} - ${song.artist}',
              style: const TextStyle(
                fontSize: 14,
                color: MonoPulseColors.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            ...bands.map(
              (band) => ListTile(
                leading: const CircleAvatar(child: Icon(Icons.groups)),
                title: Text(band.name),
                subtitle: Text('${band.members.length} members'),
                onTap: () {
                  Navigator.pop(context);
                  _addToBand(context, ref, song, band.id);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Add a song to a band.
  Future<void> _addToBand(
    BuildContext context,
    WidgetRef ref,
    Song song,
    String bandId,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      await ref
          .read(firestoreProvider)
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
